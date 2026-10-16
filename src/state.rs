//! Main compositor state
//!
//! This holds the Smithay protocol states and the two trees that form
//! Hayashi's architecture. The display tree controls window geometry:
//! when windows are added or removed, the tree is rebuilt and windows
//! are repositioned according to their assigned zones.

use std::collections::HashMap;
use std::ffi::OsString;
use std::process::Child;
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
use crate::input::PeekState;
use crate::tree::{
    build_equal_hsplit, build_equal_vsplit, Direction, DisplayTree, Rect, ZoneId, Workspace,
    WorkspaceTree,
};

/// The main compositor state.
///
/// Hayashi's architecture centers on two distinct tree structures:
/// - Display trees: Binary trees that subdivide screen space into zones (stored per-workspace as `local_display`)
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

    /// The workspace tree (hierarchy).
    /// Each workspace node holds its own display tree (`local_display`).
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

    /// Processes we launched. Kept so they can be reaped, and so their first
    /// window can be placed in the workspace that launched them.
    pub spawned: Vec<SpawnedClient>,
}

/// A process launched by the compositor.
pub struct SpawnedClient {
    pub child: Child,
    /// Workspace the process's first window should open in. Cleared once
    /// that window maps.
    pub workspace: Option<usize>,
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
            spawned: Vec::new(),
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
    /// Walks the workspace tree from root, computing geometry for each visible
    /// leaf workspace via zone claims, then positions windows within each leaf.
    pub fn relayout(&mut self) {
        let Some(output) = self.space.outputs().next().cloned() else {
            return;
        };
        let Some(output_geo) = self.space.output_geometry(&output) else {
            return;
        };

        let output_rect = Rect::new(
            output_geo.loc.x,
            output_geo.loc.y,
            output_geo.size.w as u32,
            output_geo.size.h as u32,
        );

        // Unmap all windows from the space
        let old_elements: Vec<_> = self.space.elements().cloned().collect();
        for window in &old_elements {
            self.space.unmap_elem(window);
        }
        self.windows.clear();

        // Walk the workspace tree to find all visible leaf workspaces
        let root = self.workspace_tree.root;
        let visible = self.workspace_tree.visible_leaves(root, &[output_rect]);

        // Position windows for each visible leaf workspace
        for (ws_idx, ws_rects) in &visible {
            let ws_windows = match self.workspace_windows.get(ws_idx) {
                Some(w) if !w.is_empty() => w,
                _ => continue,
            };

            let n = ws_windows.len();

            // Distribute windows across the workspace's rects.
            // For a single rect (common case), all windows go there.
            // For multiple rects (L-shape), distribute roughly evenly.
            let per_rect = n / ws_rects.len();
            let remainder = n % ws_rects.len();
            let mut window_idx = 0;

            for (rect_i, rect) in ws_rects.iter().enumerate() {
                let count = per_rect + if rect_i < remainder { 1 } else { 0 };
                if count == 0 {
                    continue;
                }

                let tree_root = build_equal_hsplit(count);
                let zones = tree_root.subdivide(*rect);

                for (i, window) in ws_windows[window_idx..window_idx + count]
                    .iter()
                    .enumerate()
                {
                    if let Some(zone) = zones.get(i) {
                        window.toplevel().unwrap().with_pending_state(|state| {
                            state.size = Some((zone.width as i32, zone.height as i32).into());
                        });
                        window.toplevel().unwrap().send_configure();
                        self.space
                            .map_element(window.clone(), (zone.x, zone.y), false);
                        self.windows.push(window.clone());
                    }
                }

                window_idx += count;
            }
        }
    }

    /// Remove windows that are no longer alive and relayout if needed.
    pub fn cleanup_windows(&mut self) {
        let mut needs_relayout = false;

        // Clean up dead windows from all workspaces
        for windows in self.workspace_windows.values_mut() {
            let before = windows.len();
            windows.retain(|w| w.toplevel().is_some_and(|t| t.alive()));
            if windows.len() != before {
                needs_relayout = true;
            }
        }

        // Reap exited launches. One that exits without ever mapping a window
        // releases its workspace so it can be pruned.
        let before = self.spawned.len();
        self.spawned
            .retain_mut(|s| !matches!(s.child.try_wait(), Ok(Some(_)) | Err(_)));
        let spawn_exited = self.spawned.len() != before;

        if needs_relayout || spawn_exited {
            needs_relayout |= self.prune_empty_workspaces();
        }

        if needs_relayout {
            self.relayout();

            // Fix focused_window index
            if self.windows.is_empty() {
                self.focused_window = None;
            } else if let Some(idx) = self.focused_window {
                if idx >= self.windows.len() {
                    self.focused_window = Some(self.windows.len() - 1);
                }
            }
            if let Some(idx) = self.focused_window {
                self.focus_window(idx);
            }
        }
    }

    /// Remove empty leaf workspaces, along with ancestors left empty by that.
    ///
    /// A workspace is kept if it has windows, has focus or is the leaf the
    /// focused container is showing, is waiting for a launched client's
    /// window, or is the root's only child (so the root always stays a
    /// container and never holds windows itself). Nothing is pruned while
    /// peeking, since a cancel has to be able to return to the origin.
    /// Returns true if anything was removed.
    pub fn prune_empty_workspaces(&mut self) -> bool {
        if self.input_mode.is_peeking() {
            return false;
        }

        let mut removed_any = false;
        loop {
            let tree = &self.workspace_tree;
            let shown = tree.leaf_under(tree.focus);
            let candidate = (0..tree.nodes.len()).find(|&idx| {
                let Some(parent) = tree.parent(idx) else {
                    return false; // root, or already removed
                };
                tree.is_live(idx)
                    && idx != shown
                    && tree.children(idx).is_empty()
                    && !(parent == tree.root && tree.children(parent).len() == 1)
                    && !self.workspace_windows.get(&idx).is_some_and(|w| !w.is_empty())
                    && !self.spawned.iter().any(|s| s.workspace == Some(idx))
            });
            let Some(idx) = candidate else {
                break;
            };

            info!(
                "Removing empty workspace: {}",
                self.workspace_tree.path_string(idx)
            );
            self.workspace_tree.remove(idx);
            self.workspace_windows.remove(&idx);
            removed_any = true;
        }
        removed_any
    }

    /// Pick the workspace a new toplevel should be placed in.
    ///
    /// A window from a process we launched for a workspace goes there; any
    /// other window goes to the focused workspace. Either way it lands on a
    /// leaf, since windows on a container are never laid out.
    pub fn workspace_for_new_window(&mut self, pid: Option<i32>) -> usize {
        let launched_for = pid.and_then(|pid| {
            let pending: Vec<u32> = self
                .spawned
                .iter()
                .filter(|s| s.workspace.is_some())
                .map(|s| s.child.id())
                .collect();
            let launcher = process_and_ancestors(pid as u32).find(|p| pending.contains(p))?;
            self.spawned
                .iter_mut()
                .find(|s| s.child.id() == launcher)?
                .workspace
                .take()
        });

        let target = launched_for
            .filter(|&ws| self.workspace_tree.is_live(ws))
            .unwrap_or(self.workspace_tree.focus);
        self.workspace_tree.leaf_under(target)
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

    /// Get the current zone rectangles for all visible windows.
    fn current_zones(&self) -> Vec<Rect> {
        self.windows
            .iter()
            .filter_map(|w| {
                self.space.element_geometry(w).map(|geo| {
                    Rect::new(geo.loc.x, geo.loc.y, geo.size.w as u32, geo.size.h as u32)
                })
            })
            .collect()
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

    /// Switch to a workspace by index.
    ///
    /// Updates the active path in the workspace tree and relayouts.
    /// Windows are stored per-workspace in workspace_windows; the visible set
    /// is recomputed from the tree walk.
    fn switch_to_workspace(&mut self, target_idx: usize) {
        let current = self.workspace_tree.focus;
        if target_idx == current {
            return;
        }

        // Activate the path from root to the target workspace
        self.workspace_tree.activate_path(target_idx);
        self.workspace_tree.focus = target_idx;
        self.prune_empty_workspaces();

        // Relayout (recomputes visible windows from tree walk)
        self.relayout();

        // Focus the first window in the target workspace
        if let Some(target_windows) = self.workspace_windows.get(&target_idx) {
            if let Some(first) = target_windows.first() {
                if let Some(idx) = self.windows.iter().position(|w| w == first) {
                    self.focus_window(idx);
                    return;
                }
            }
        }

        // No windows to focus
        self.focused_window = None;
        let serial = SERIAL_COUNTER.next_serial();
        let keyboard = self.seat.get_keyboard().unwrap();
        keyboard.set_focus(self, Option::<WlSurface>::None, serial);
    }

    /// Handle Mod+<letter>: enter peek mode or continue the current search,
    /// and preview the result.
    ///
    /// Search behavior follows SPEC.md and KEYBINDINGS.md:
    /// - The first press searches upward from the origin and peeks the first match
    /// - The same letter again continues upward and peeks the next match
    /// - When the matches run out, previews creating the workspace at the
    ///   origin; pressing again from there starts over at the first match
    /// - A different letter restarts the search from the origin
    pub fn peek_search(&mut self, key: char) {
        if !self.input_mode.is_peeking() {
            self.input_mode = InputMode::Peeking(PeekState {
                original_tree: self.workspace_tree.clone(),
                original_window: self.focused_window.and_then(|i| self.windows.get(i).cloned()),
                search_key: None,
                next_search: None,
                tentative: None,
            });
        }
        let InputMode::Peeking(peek) = &mut self.input_mode else {
            return;
        };
        let origin = peek.original_tree.focus;

        let restart = peek.search_key != Some(key) || peek.tentative.is_some();
        let start = if restart { Some(origin) } else { peek.next_search };
        peek.search_key = Some(key);

        // Searching on discards a previewed creation
        if let Some(tentative) = peek.tentative.take() {
            self.workspace_tree.remove(tentative);
        }

        let found = start.and_then(|s| self.workspace_tree.find_next_by_name(key, s));
        let target = match found {
            Some((idx, next)) => {
                if let InputMode::Peeking(peek) = &mut self.input_mode {
                    peek.next_search = next;
                }
                idx
            }
            None => {
                let idx = self
                    .workspace_tree
                    .add_child(self.creation_parent(origin), Workspace::with_name(key));
                if let InputMode::Peeking(peek) = &mut self.input_mode {
                    peek.next_search = None;
                    peek.tentative = Some(idx);
                }
                idx
            }
        };

        info!("Peeking: {}", self.workspace_tree.path_string(target));
        self.switch_to_workspace(target);
    }

    /// Where a workspace created from `origin` goes (KEYBINDINGS.md):
    /// - If origin holds windows, the new workspace is its sibling
    /// - If origin is a container (or empty), the new workspace is its child
    fn creation_parent(&self, origin: usize) -> usize {
        let has_windows = self
            .workspace_windows
            .get(&origin)
            .is_some_and(|w| !w.is_empty());
        if has_windows {
            self.workspace_tree.parent(origin).unwrap_or(origin)
        } else {
            origin
        }
    }

    /// Commit the peeked workspace (Super released): it stays focused, a
    /// previewed creation becomes real and gets a launcher, and workspaces
    /// left empty are cleaned up. Does nothing outside peek mode.
    pub fn commit_peek(&mut self) {
        let InputMode::Peeking(peek) = std::mem::replace(&mut self.input_mode, InputMode::Normal)
        else {
            return;
        };

        info!(
            "Committed to workspace: {}",
            self.workspace_tree.path_string(self.workspace_tree.focus)
        );
        if let Some(created) = peek.tentative {
            self.spawn_launcher(created);
        }

        if self.prune_empty_workspaces() {
            let focused = self.focused_window.and_then(|i| self.windows.get(i).cloned());
            self.relayout();
            self.refocus(focused.as_ref());
        }
    }

    /// Cancel peek mode (Escape): put the workspace tree, layout, and
    /// keyboard focus back the way they were before peeking.
    pub fn cancel_peek(&mut self) {
        let InputMode::Peeking(peek) = std::mem::replace(&mut self.input_mode, InputMode::Normal)
        else {
            return;
        };

        self.workspace_tree.restore(peek.original_tree);
        info!(
            "Peek cancelled, back to: {}",
            self.workspace_tree.path_string(self.workspace_tree.focus)
        );

        // A client may have mapped a window into the previewed creation,
        // which no longer exists; move it to where focus is now.
        let orphaned: Vec<usize> = self
            .workspace_windows
            .keys()
            .copied()
            .filter(|&ws| !self.workspace_tree.is_live(ws))
            .collect();
        let home = self.workspace_tree.leaf_under(self.workspace_tree.focus);
        for ws in orphaned {
            if let Some(windows) = self.workspace_windows.remove(&ws) {
                self.workspace_windows.entry(home).or_default().extend(windows);
            }
        }

        self.relayout();
        self.refocus(peek.original_window.as_ref());
    }

    /// Give keyboard focus to `window` if it's still visible, or clear it.
    fn refocus(&mut self, window: Option<&Window>) {
        if let Some(idx) = window.and_then(|w| self.windows.iter().position(|v| v == w)) {
            self.focus_window(idx);
            return;
        }
        self.focused_window = None;
        let serial = SERIAL_COUNTER.next_serial();
        let keyboard = self.seat.get_keyboard().unwrap();
        keyboard.set_focus(self, Option::<WlSurface>::None, serial);
    }

    /// Spawn a terminal for a new workspace.
    ///
    /// The process is remembered so its first window opens in `workspace`
    /// even if focus has moved on by the time it maps.
    /// TODO: Replace with launcher (rofi/fuzzel) once layer shell is supported.
    fn spawn_launcher(&mut self, workspace: usize) {
        info!("Launching foot for new workspace");
        match std::process::Command::new("foot").spawn() {
            Ok(child) => self.spawned.push(SpawnedClient {
                child,
                workspace: Some(workspace),
            }),
            Err(e) => info!("Failed to launch foot: {e}"),
        }
    }

    /// Focus the parent workspace (move up the tree).
    ///
    /// The visual layout doesn't change — we just move the interaction focus
    /// up to the container level. From there, Mod+letter switches between
    /// children, and Mod+Shift+d descends back in.
    pub fn focus_parent_workspace(&mut self) {
        let current = self.workspace_tree.focus;
        if let Some(parent) = self.workspace_tree.parent(current) {
            info!(
                "Focusing parent workspace: {}",
                self.workspace_tree.path_string(parent)
            );
            self.workspace_tree.focus = parent;
            if self.prune_empty_workspaces() {
                self.relayout();
            }
            // Clear window focus — we're at a container level now
            self.focused_window = None;
            let serial = SERIAL_COUNTER.next_serial();
            let keyboard = self.seat.get_keyboard().unwrap();
            keyboard.set_focus(self, Option::<WlSurface>::None, serial);
        }
    }

    /// Focus the active child workspace (move down the tree).
    pub fn focus_child_workspace(&mut self) {
        let current = self.workspace_tree.focus;
        if let Some(active) = self.workspace_tree.nodes[current].active_child {
            info!(
                "Focusing child workspace: {}",
                self.workspace_tree.path_string(active)
            );
            self.workspace_tree.focus = active;

            // Focus the first window of the child if it has any
            if let Some(windows) = self.workspace_windows.get(&active) {
                if let Some(first) = windows.first() {
                    if let Some(idx) = self.windows.iter().position(|w| w == first) {
                        self.focus_window(idx);
                        return;
                    }
                }
            }

            // No windows — keep descending or clear focus
            self.focused_window = None;
        }
    }

    /// Split the parent's display tree, adding one more zone.
    ///
    /// All children keep their existing zone claims (typically zone 0).
    /// Use move_workspace (Mod+Ctrl+h/j/k/l) to assign workspaces to the new zone.
    pub fn split_parent_zone(&mut self, direction: Direction) {
        let current = self.workspace_tree.focus;
        let Some(parent) = self.workspace_tree.parent(current) else {
            return;
        };

        let current_count = self.workspace_tree.nodes[parent]
            .local_display
            .root
            .zone_count();
        let new_count = current_count + 1;

        // Rebuild parent's display tree with one more zone
        let tree_root = match direction {
            Direction::Horizontal => build_equal_hsplit(new_count),
            Direction::Vertical => build_equal_vsplit(new_count),
        };
        self.workspace_tree.nodes[parent].local_display.root = tree_root;

        // Children keep their existing zone claims — move them with Mod+Ctrl+hjkl

        info!(
            "Split {} into {} zones ({:?})",
            self.workspace_tree.path_string(parent),
            new_count,
            direction
        );
        self.relayout();
    }

    /// Merge parent's zones back to stacked (all children share zone 0).
    pub fn merge_parent_zones(&mut self) {
        let current = self.workspace_tree.focus;
        let Some(parent) = self.workspace_tree.parent(current) else {
            return;
        };

        let children = self.workspace_tree.children(parent);

        // Reset parent's display tree to single zone
        self.workspace_tree.nodes[parent].local_display = DisplayTree::new();

        // All children claim zone 0 (stacked)
        for child_idx in &children {
            self.workspace_tree.nodes[*child_idx].claims = vec![ZoneId(0)];
        }

        info!(
            "Merged zones in {}",
            self.workspace_tree.path_string(parent)
        );
        self.relayout();
    }

    /// Move the focused workspace to an adjacent zone in the given direction.
    ///
    /// The direction is spatial: we compute zone rects from the parent's display
    /// tree and find the nearest zone in the requested direction.
    pub fn move_workspace(&mut self, dx: i32, dy: i32) {
        let current = self.workspace_tree.focus;
        let Some(parent) = self.workspace_tree.parent(current) else {
            return;
        };

        let current_zone = self.workspace_tree.nodes[current]
            .claims
            .first()
            .map(|z| z.0)
            .unwrap_or(0);

        // Subdivide parent's display tree to get zone positions
        let ref_rect = Rect::new(0, 0, 10000, 10000);
        let zones = self.workspace_tree.nodes[parent]
            .local_display
            .subdivide(ref_rect);

        if zones.len() < 2 {
            return;
        }

        let Some(current_rect) = zones.get(current_zone) else {
            return;
        };
        let cx = current_rect.x + current_rect.width as i32 / 2;
        let cy = current_rect.y + current_rect.height as i32 / 2;

        // Find the closest zone in the requested direction
        let mut best: Option<(usize, i32)> = None;
        for (i, zone) in zones.iter().enumerate() {
            if i == current_zone {
                continue;
            }

            let zx = zone.x + zone.width as i32 / 2;
            let zy = zone.y + zone.height as i32 / 2;

            let in_direction = match (dx, dy) {
                (-1, 0) => zx < cx,
                (1, 0) => zx > cx,
                (0, -1) => zy < cy,
                (0, 1) => zy > cy,
                _ => false,
            };

            if !in_direction {
                continue;
            }

            let dist = (zx - cx).abs() + (zy - cy).abs();
            if best.is_none() || dist < best.unwrap().1 {
                best = Some((i, dist));
            }
        }

        if let Some((target_zone, _)) = best {
            self.workspace_tree.nodes[current].claims = vec![ZoneId(target_zone)];
            info!(
                "Moved {} to zone {}",
                self.workspace_tree.path_string(current),
                target_zone
            );
            self.relayout();
        }
    }

    /// Dispatch a compositor action.
    ///
    /// Mod+<letter> and Escape drive peek mode. Any other action commits an
    /// active peek first and then runs, so Escape only ever has to undo the
    /// search itself.
    pub fn handle_action(&mut self, action: Action) {
        match action {
            Action::SwitchWorkspace(name) => return self.peek_search(name),
            Action::CancelPeek => return self.cancel_peek(),
            Action::CommitPeek => return self.commit_peek(),
            _ => self.commit_peek(),
        }

        match action {
            Action::SwitchWorkspace(_) | Action::CancelPeek | Action::CommitPeek => {}
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
            Action::FocusParent => self.focus_parent_workspace(),
            Action::FocusChild => self.focus_child_workspace(),
            Action::SplitZoneH => self.split_parent_zone(Direction::Horizontal),
            Action::SplitZoneV => self.split_parent_zone(Direction::Vertical),
            Action::MergeZones => self.merge_parent_zones(),
            Action::MoveLeft => self.move_workspace(-1, 0),
            Action::MoveRight => self.move_workspace(1, 0),
            Action::MoveUp => self.move_workspace(0, -1),
            Action::MoveDown => self.move_workspace(0, 1),
        }
    }
}

/// Iterate over a pid and its ancestors (parent, grandparent, ...), so a
/// window from a process started by a wrapper script still matches the pid
/// we launched. Stops at init or when /proc can't be read.
fn process_and_ancestors(pid: u32) -> impl Iterator<Item = u32> {
    std::iter::successors(Some(pid), |&pid| {
        let stat = std::fs::read_to_string(format!("/proc/{pid}/stat")).ok()?;
        // Format is "pid (comm) state ppid ..."; comm may contain spaces or
        // parens, so parse from the last ')'.
        let after_comm = &stat[stat.rfind(')')? + 1..];
        let ppid: u32 = after_comm.split_whitespace().nth(1)?.parse().ok()?;
        (ppid > 1).then_some(ppid)
    })
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
