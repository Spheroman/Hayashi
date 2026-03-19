//! Backend abstraction
//!
//! Hayashi supports multiple backends:
//! - Winit: For development/testing in a window
//! - DRM/KMS: For running as the actual display server (future)

pub mod winit;

/// Backend trait that all backends must implement.
pub trait Backend {
    /// Initialize the backend.
    fn init() -> anyhow::Result<Self>
    where
        Self: Sized;

    /// Run the event loop.
    fn run(&mut self) -> anyhow::Result<()>;
}
