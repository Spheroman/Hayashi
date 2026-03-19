//! Main compositor state
//!
//! This holds the Smithay protocol states and the two trees that form
//! Hayashi's architecture. The display tree controls window geometry:
//! when windows are added or removed, the tree is rebuilt and windows
//! are repositioned according to their assigned zones.

use std::collections::HashMap;
use std::ffi::OsString;
use std::sync::Arc;

use smithay::desktop::{PopupManager, Space, Window, WindowSurfaceType};
use smithay::input::{Seat, SeatState};
use smithay::reexports::calloop::generic::Generic;
use smithay::reexports::calloop::{EventLoop, Interest, LoopSignal, Mode, PostAction};
use smithay::reexports::wayland_server::backend::{ClientData, ClientId, DisconnectReason};
use smithay::reexports::wayland_server::protocol::wl_surface::WlSurface;
use smithay::reexports::wayland_server::{Display, DisplayHandle};
use smithay::utils::{Logical, Point, SERIAL_COUNTER};
use smithay::wayland::compositor::{CompositorClientState, CompositorState};
use smithay::wayland::output::OutputManagerState;
use smithay::wayland::selection::data_device::DataDeviceState;
use smithay::wayland::shell::xdg::XdgShellState;
use smithay::wayland::shm::ShmState;
use smithay::wayland::socket::ListeningSocketSource;

use tracing::info;

use crate::input::Action;
use crate::input::Mode as InputMode;
use crate::tree::{build_equal_hsplit, DisplayTree, Rect, Workspace, WorkspaceTree};

/// The main compositor state.
///
/// Hayashi's architecture centers on two distinct tree structures:
/// - `display_trees`: Binary trees that subdivide screen space into zones
/// - `workspace_tree`: N-ary tree of workspaces that claim zones
///
/// The display tree drives window positioning: each mapped window is assigned
/// a zone, and the tree is rebuilt when windows are added or removed.
pub struct Hayashi {
    pub start_time: std::time::Instant,
    pub socket_name: OsString,
    pub display_handle: DisplayHandle,

    /// Smithay Space for rendering and hit-testing.
    pub space: Space<Window>,
    pub loop_signal: LoopSignal,
    pub popups: PopupManager,

    // Smithay protocol states
    pub compositor_state: CompositorState,
    pub xdg_shell_state: XdgShellState,
    pub shm_state: ShmState,
    pub output_manager_state: OutputManagerState,
    pub seat_state: SeatState<Hayashi>,
    pub data_device_state: DataDeviceState,

    /// The input seat (keyboard + pointer).
    pub seat: Seat<Self>,

    // --- Hayashi-specific state ---

    /// Tiled windows in layout order. The display tree assigns each
    /// window a zone by index (window 0 → zone 0, etc.).
    pub windows: Vec<Window>,

    /// The display trees (geometry) — one per output.
    pub display_trees: Vec<DisplayTree>,

    /// The workspace tree (hierarchy).
    pub workspace_tree: WorkspaceTree,

    /// Current interaction mode (Normal or Peeking).
    pub input_mode: InputMode,

    /// Currently focused workspace node.
    pub focus: Option<usize>,

    /// Currently focused window index (into self.windows).
    pub focused_window: Option<usize>,

    /// Windows stored per-workspace (for inactive workspaces).
    /// Active workspace's windows live in `self.windows`.
    pub workspace_windows: HashMap<usize, Vec<Window>>,
}

impl Hayashi {
    pub fn new(event_loop: &mut EventLoop<Self>, display: Display<Self>) -> Self {
        let start_time = std::time::Instant::now();
        let dh = display.handle();

        // Initialize Wayland protocol implementations
        let compositor_state = CompositorState::new::<Self>(&dh);
        let xdg_shell_state = XdgShellState::new::<Self>(&dh);
        let shm_state = ShmState::new::<Self>(&dh, vec![]);
        let output_manager_state = OutputManagerState::new_with_xdg_output::<Self>(&dh);
        let data_device_state = DataDeviceState::new::<Self>(&dh);
        let popups = PopupManager::default();

        // Create input seat with keyboard and pointer
        let mut seat_state = SeatState::new();
        let mut seat: Seat<Self> = seat_state.new_wl_seat(&dh, "hayashi");
        seat.add_keyboard(Default::default(), 200, 25)
            .expect("Failed to add keyboard");
        seat.add_pointer();

        let space = Space::default();

        // Set up Wayland socket for client connections
        let socket_name = Self::init_wayland_listener(display, event_loop);
        info!("Listening on Wayland socket: {:?}", socket_name);

        let loop_signal = event_loop.get_signal();

        Self {
            start_time,
            display_handle: dh,
            socket_name,

            space,
            loop_signal,
            popups,

            compositor_state,
            xdg_shell_state,
            shm_state,
            output_manager_state,
            seat_state,
            data_device_state,
            seat,

            windows: Vec::new(),
            display_trees: Vec::new(),
            workspace_tree: {
                let mut tree = WorkspaceTree::new();
                let default_ws = tree.add_child(tree.root, Workspace::with_name('a'));
                tree.focus = default_ws;
                tree
            },
            input_mode: InputMode::Normal,
            focus: None,
            focused_window: None,
            workspace_windows: HashMap::new(),
        }
    }

    fn init_wayland_listener(
        display: Display<Hayashi>,
        event_loop: &mut EventLoop<Self>,
    ) -> OsString {
        let listening_socket = ListeningSocketSource::new_auto()
            .expect("Failed to create Wayland listening socket");

        let socket_name = listening_socket.socket_name().to_os_string();

        let loop_handle = event_loop.handle();

        loop_handle
            .insert_source(listening_socket, move |client_stream, _, state| {
                state
                    .display_handle
                    .insert_client(client_stream, Arc::new(ClientState::default()))
                    .unwrap();
            })
            .expect("Failed to init the Wayland event source");

        loop_handle
            .insert_source(
                Generic::new(display, Interest::READ, Mode::Level),
                |_, display, state| {
                    // Safety: we don't drop the display
                    unsafe {
                        display.get_mut().dispatch_clients(state).unwrap();
                    }
                    Ok(PostAction::Continue)
                },
            )
            .unwrap();

        socket_name
    }

    /// Rebuild the display tree and reposition all windows according to their zones.
    ///
    /// Called when windows are added/removed or the output is resized.
    pub fn relayout(&mut self) {
        let Some(output) = self.space.outputs().next().cloned() else {
            return;
        };
        let output_geo = self.space.output_geometry(&output).unwrap();

        let n = self.windows.len();
        if n == 0 {
            return;
        }

        // Build a display tree with one zone per window, split equally
        let tree_root = build_equal_hsplit(n);

        // Persist the display tree for this output
        if self.display_trees.is_empty() {
            self.display_trees.push(DisplayTree::new());
        }
        self.display_trees[0].root = tree_root;

        // Compute zone rectangles from output geometry
        let rect = Rect::new(
            output_geo.loc.x,
            output_geo.loc.y,
            output_geo.size.w as u32,
            output_geo.size.h as u32,
        );
        let zones = self.display_trees[0].subdivide(rect);

        // Configure and position each window in its zone
        for (i, window) in self.windows.iter().enumerate() {
            if let Some(zone) = zones.get(i) {
                window.toplevel().unwrap().with_pending_state(|state| {
                    state.size = Some((zone.width as i32, zone.height as i32).into());
                });
                window.toplevel().unwrap().send_configure();
                self.space.map_element(window.clone(), (zone.x, zone.y), false);
            }
        }
    }

    /// Remove windows that are no longer alive and relayout if needed.
    pub fn cleanup_windows(&mut self) {
        let before = self.windows.len();
        // Collect live surfaces from the space to avoid borrow conflicts
        let live_surfaces: Vec<_> = self
            .space
            .elements()
            .map(|w| w.toplevel().unwrap().wl_surface().clone())
            .collect();
        self.windows.retain(|w| {
            let surface = w.toplevel().unwrap().wl_surface().clone();
            live_surfaces.contains(&surface)
        });
        if self.windows.len() != before {
            // Fix focused_window index after removal
            if self.windows.is_empty() {
                self.focused_window = None;
            } else if let Some(idx) = self.focused_window {
                if idx >= self.windows.len() {
                    self.focused_window = Some(self.windows.len() - 1);
                }
            }
            self.relayout();
            // Re-focus if we still have a focused window
            if let Some(idx) = self.focused_window {
                self.focus_window(idx);
            }
        }
    }

    /// Find the surface under a given point in the space.
    pub fn surface_under(
        &self,
        pos: Point<f64, Logical>,
    ) -> Option<(WlSurface, Point<f64, Logical>)> {
        self.space
            .element_under(pos)
            .and_then(|(window, location)| {
                window
                    .surface_under(pos - location.to_f64(), WindowSurfaceType::ALL)
                    .map(|(s, p)| (s, (p + location).to_f64()))
            })
    }

    // --- Focus management ---

    /// Set keyboard focus to the window at the given index.
    pub fn focus_window(&mut self, idx: usize) {
        if idx >= self.windows.len() {
            return;
        }

        self.focused_window = Some(idx);
        let window = self.windows[idx].clone();

        let serial = SERIAL_COUNTER.next_serial();
        let keyboard = self.seat.get_keyboard().unwrap();
        keyboard.set_focus(
            self,
            Some(window.toplevel().unwrap().wl_surface().clone()),
            serial,
        );

        // Update activation state on all windows
        for w in self.windows.iter() {
            w.set_activated(w == &window);
            w.toplevel().unwrap().send_pending_configure();
        }
    }

    /// Focus the next window in the list (wrapping around).
    pub fn focus_next(&mut self) {
        if self.windows.is_empty() {
            return;
        }
        let next = match self.focused_window {
            Some(idx) => (idx + 1) % self.windows.len(),
            None => 0,
        };
        self.focus_window(next);
    }

    /// Focus the previous window in the list (wrapping around).
    pub fn focus_prev(&mut self) {
        if self.windows.is_empty() {
            return;
        }
        let prev = match self.focused_window {
            Some(idx) => {
                if idx == 0 {
                    self.windows.len() - 1
                } else {
                    idx - 1
                }
            }
            None => self.windows.len() - 1,
        };
        self.focus_window(prev);
    }

    /// Focus the nearest window in the given direction based on zone geometry.
    pub fn focus_direction(&mut self, dx: i32, dy: i32) {
        let current = match self.focused_window {
            Some(idx) => idx,
            None => return,
        };

        let zones = self.current_zones();
        if zones.is_empty() {
            return;
        }

        let current_zone = match zones.get(current) {
            Some(z) => z,
            None => return,
        };

        // Center of the current window's zone
        let cx = current_zone.x + current_zone.width as i32 / 2;
        let cy = current_zone.y + current_zone.height as i32 / 2;

        let mut best: Option<(usize, i32)> = None;

        for (i, zone) in zones.iter().enumerate() {
            if i == current {
                continue;
            }

            let zx = zone.x + zone.width as i32 / 2;
            let zy = zone.y + zone.height as i32 / 2;

            // Check if this window is in the requested direction
            let in_direction = match (dx, dy) {
                (-1, 0) => zx < cx, // left
                (1, 0) => zx > cx,  // right
                (0, -1) => zy < cy, // up
                (0, 1) => zy > cy,  // down
                _ => false,
            };

            if !in_direction {
                continue;
            }

            // Manhattan distance
            let dist = (zx - cx).abs() + (zy - cy).abs();

            if best.is_none() || dist < best.unwrap().1 {
                best = Some((i, dist));
            }
        }

        if let Some((idx, _)) = best {
            self.focus_window(idx);
        }
    }

    /// Get the current zone rectangles for all windows.
    fn current_zones(&self) -> Vec<Rect> {
        let Some(output) = self.space.outputs().next().cloned() else {
            return Vec::new();
        };
        let Some(output_geo) = self.space.output_geometry(&output) else {
            return Vec::new();
        };

        if self.windows.is_empty() || self.display_trees.is_empty() {
            return Vec::new();
        }

        let rect = Rect::new(
            output_geo.loc.x,
            output_geo.loc.y,
            output_geo.size.w as u32,
            output_geo.size.h as u32,
        );
        self.display_trees[0].subdivide(rect)
    }

    /// Close the currently focused window.
    pub fn close_focused_window(&mut self) {
        if let Some(idx) = self.focused_window {
            if let Some(window) = self.windows.get(idx) {
                window.toplevel().unwrap().send_close();
            }
        }
    }

    // --- Workspace management ---

    /// Switch to a workspace by index, saving/restoring windows.
    fn switch_to_workspace(&mut self, target_idx: usize) {
        let current = self.workspace_tree.focus;
        if target_idx == current {
            return;
        }

        // Save current windows and unmap from space
        let current_windows: Vec<Window> = self.windows.drain(..).collect();
        for w in &current_windows {
            self.space.unmap_elem(w);
        }
        self.workspace_windows.insert(current, current_windows);

        // Switch focus in workspace tree
        self.workspace_tree.focus = target_idx;

        // Load target workspace's windows
        self.windows = self.workspace_windows.remove(&target_idx).unwrap_or_default();

        // Map windows into space
        for window in &self.windows {
            self.space.map_element(window.clone(), (0, 0), false);
        }

        // Relayout and refocus
        self.relayout();

        if !self.windows.is_empty() {
            self.focus_window(0);
        } else {
            self.focused_window = None;
            let serial = SERIAL_COUNTER.next_serial();
            let keyboard = self.seat.get_keyboard().unwrap();
            keyboard.set_focus(self, Option::<WlSurface>::None, serial);
        }
    }

    /// Switch to (or create) a workspace by name.
    ///
    /// Creation context follows KEYBINDINGS.md:
    /// - If focused on a window (workspace has windows), creates as sibling
    /// - If focused on a container (empty workspace), creates as child
    pub fn switch_workspace(&mut self, name: char) {
        let current = self.workspace_tree.focus;

        // Search from current workspace upward
        let (target_idx, created) = match self.workspace_tree.find_by_name(name, current) {
            Some(idx) => (idx, false),
            None => {
                // Creation context: window-focused → sibling, container → child
                let create_parent = if self.windows.is_empty() {
                    // Container context: create as child of current workspace
                    current
                } else {
                    // Window context: create as sibling (child of parent)
                    self.workspace_tree.parent(current).unwrap_or(current)
                };
                let idx = self.workspace_tree.add_child(create_parent, Workspace::with_name(name));
                (idx, true)
            }
        };

        info!("Switching to workspace: {}", self.workspace_tree.path_string(target_idx));
        self.switch_to_workspace(target_idx);

        if created {
            self.spawn_launcher();
        }
    }

    /// Spawn a terminal in the new workspace.
    /// TODO: Replace with launcher (rofi/fuzzel) once layer shell is supported.
    fn spawn_launcher(&self) {
        info!("Launching foot for new workspace");
        if let Err(e) = std::process::Command::new("foot").spawn() {
            info!("Failed to launch foot: {e}");
        }
    }

    /// Focus the parent workspace.
    pub fn focus_parent_workspace(&mut self) {
        let current = self.workspace_tree.focus;
        if let Some(parent) = self.workspace_tree.parent(current) {
            info!("Switching to parent workspace: {}", self.workspace_tree.path_string(parent));
            self.switch_to_workspace(parent);
        }
    }

    /// Dispatch a compositor action.
    pub fn handle_action(&mut self, action: Action) {
        match action {
            Action::CloseWindow => self.close_focused_window(),
            Action::Exit => {
                info!("Exit requested");
                self.loop_signal.stop();
            }
            Action::FocusLeft => self.focus_direction(-1, 0),
            Action::FocusRight => self.focus_direction(1, 0),
            Action::FocusUp => self.focus_direction(0, -1),
            Action::FocusDown => self.focus_direction(0, 1),
            Action::FocusNext => self.focus_next(),
            Action::FocusPrev => self.focus_prev(),
            Action::SwitchWorkspace(name) => self.switch_workspace(name),
            Action::FocusParent => self.focus_parent_workspace(),
        }
    }
}

/// Data associated with each connected Wayland client.
#[derive(Default)]
pub struct ClientState {
    pub compositor_state: CompositorClientState,
}

impl ClientData for ClientState {
    fn initialized(&self, _client_id: ClientId) {}
    fn disconnected(&self, _client_id: ClientId, _reason: DisconnectReason) {}
}
