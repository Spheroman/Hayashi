//! Hayashi (林) - A Wayland compositor with nested hierarchical workspaces
//!
//! Two trees, separate concerns:
//! - Display tree: handles geometry (binary tree subdividing screen space)
//! - Workspace tree: handles hierarchy and focus (n-ary tree of workspaces)

mod backend;
mod config;
mod input;
mod state;
mod tree;

use anyhow::Result;
use tracing::info;
use tracing_subscriber::{fmt, prelude::*, EnvFilter};

fn main() -> Result<()> {
    // Initialize logging
    tracing_subscriber::registry()
        .with(fmt::layer())
        .with(EnvFilter::from_default_env().add_directive("hayashi=debug".parse()?))
        .init();

    info!("🌲 Hayashi starting...");

    // TODO: Milestone 1 - Display one window
    // 1. Initialize backend (winit for development, DRM for production)
    // 2. Create EGL context
    // 3. Set up basic event loop
    // 4. Render a test window

    info!("Hayashi is not yet implemented. Start with milestone 1!");
    info!("See src/backend/mod.rs for the entry point.");

    Ok(())
}
