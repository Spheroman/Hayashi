//! Main compositor state
//!
//! This holds the Smithay protocol states and the two trees that form
//! Hayashi's architecture. For milestone 1, window management is handled
//! by Smithay's `Space<Window>`, with the two-tree architecture wired in later.

use std::ffi::OsString;
use std::sync::Arc;

use smithay::desktop::{PopupManager, Space, Window, WindowSurfaceType};
use smithay::input::{Seat, SeatState};
use smithay::reexports::calloop::generic::Generic;
use smithay::reexports::calloop::{EventLoop, Interest, LoopSignal, Mode, PostAction};
use smithay::reexports::wayland_server::backend::{ClientData, ClientId, DisconnectReason};
use smithay::reexports::wayland_server::protocol::wl_surface::WlSurface;
use smithay::reexports::wayland_server::{Display, DisplayHandle};
use smithay::utils::{Logical, Point};
use smithay::wayland::compositor::{CompositorClientState, CompositorState};
use smithay::wayland::output::OutputManagerState;
use smithay::wayland::selection::data_device::DataDeviceState;
use smithay::wayland::shell::xdg::XdgShellState;
use smithay::wayland::shm::ShmState;
use smithay::wayland::socket::ListeningSocketSource;

use tracing::info;

use crate::tree::{DisplayTree, WorkspaceTree};
use crate::input::Mode as InputMode;

/// The main compositor state.
///
/// Hayashi's architecture centers on two distinct tree structures:
/// - `display_trees`: Binary trees that subdivide screen space into zones
/// - `workspace_tree`: N-ary tree of workspaces that claim zones
///
/// For milestone 1, Smithay's `Space<Window>` handles window positioning.
pub struct Hayashi {
    pub start_time: std::time::Instant,
    pub socket_name: OsString,
    pub display_handle: DisplayHandle,

    /// Smithay Space for window management (milestone 1).
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

    // --- Hayashi-specific state (wired in milestone 2+) ---

    /// The display trees (geometry) — one per output.
    pub display_trees: Vec<DisplayTree>,

    /// The workspace tree (hierarchy).
    pub workspace_tree: WorkspaceTree,

    /// Current interaction mode (Normal or Peeking).
    pub input_mode: InputMode,

    /// Currently focused workspace node.
    pub focus: Option<usize>,
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

            // Hayashi-specific (not yet active)
            display_trees: Vec::new(),
            workspace_tree: WorkspaceTree::new(),
            input_mode: InputMode::Normal,
            focus: None,
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
