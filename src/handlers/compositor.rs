//! Compositor and SHM handlers
//!
//! Handles surface commits and shared-memory buffer management.

use crate::state::ClientState;
use crate::Hayashi;

use smithay::backend::renderer::utils::on_commit_buffer_handler;
use smithay::reexports::wayland_server::protocol::wl_buffer;
use smithay::reexports::wayland_server::protocol::wl_surface::WlSurface;
use smithay::reexports::wayland_server::Client;
use smithay::wayland::buffer::BufferHandler;
use smithay::wayland::compositor::{
    get_parent, is_sync_subsurface, CompositorClientState, CompositorHandler, CompositorState,
};
use smithay::wayland::shm::{ShmHandler, ShmState};
use smithay::{delegate_compositor, delegate_shm};

use super::xdg_shell;

impl CompositorHandler for Hayashi {
    fn compositor_state(&mut self) -> &mut CompositorState {
        &mut self.compositor_state
    }

    fn client_compositor_state<'a>(&self, client: &'a Client) -> &'a CompositorClientState {
        &client.get_data::<ClientState>().unwrap().compositor_state
    }

    fn commit(&mut self, surface: &WlSurface) {
        on_commit_buffer_handler::<Self>(surface);

        if !is_sync_subsurface(surface) {
            let mut root = surface.clone();
            while let Some(parent) = get_parent(&root) {
                root = parent;
            }
            if let Some(window) = self
                .space
                .elements()
                .find(|w| w.toplevel().unwrap().wl_surface() == &root)
            {
                window.on_commit();
            }
        }

        xdg_shell::handle_commit(&mut self.popups, &self.space, surface);
    }
}

impl BufferHandler for Hayashi {
    fn buffer_destroyed(&mut self, _buffer: &wl_buffer::WlBuffer) {}
}

impl ShmHandler for Hayashi {
    fn shm_state(&self) -> &ShmState {
        &self.shm_state
    }
}

delegate_compositor!(Hayashi);
delegate_shm!(Hayashi);
