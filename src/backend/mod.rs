//! Backend abstraction
//!
//! Hayashi supports multiple backends:
//! - Winit: For development/testing in a window
//! - DRM/KMS: For running as the actual display server
//!
//! Start here for Milestone 1!

// TODO: Milestone 1 implementation steps:
//
// 1. Start with the winit backend for easy development
//    - Create a winit window
//    - Set up OpenGL/EGL context via smithay's renderer
//    - Get the basic event loop running
//
// 2. Render something simple
//    - Clear to a solid color
//    - Draw a rectangle
//    - Eventually: render an actual Wayland surface
//
// 3. Set up the Wayland server
//    - Initialize wayland-server Display
//    - Register the compositor global
//    - Handle client connections
//
// References:
// - smallvil: https://github.com/Smithay/smithay/tree/master/smallvil
// - smithay examples: https://github.com/Smithay/smithay/tree/master/examples
//
// The smallvil compositor is your best starting point. It's intentionally
// minimal and well-documented. Read through it, understand each piece,
// then adapt it for Hayashi's architecture.

/// Backend trait that all backends must implement.
pub trait Backend {
    /// Initialize the backend.
    fn init() -> anyhow::Result<Self>
    where
        Self: Sized;

    /// Run the event loop.
    fn run(&mut self) -> anyhow::Result<()>;
}

// Placeholder modules - uncomment and implement as you progress
// pub mod winit;
// pub mod drm;
