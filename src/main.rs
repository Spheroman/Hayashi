//! Hayashi (林) - A Wayland compositor with nested hierarchical workspaces
//!
//! Two trees, separate concerns:
//! - Display tree: handles geometry (binary tree subdividing screen space)
//! - Workspace tree: handles hierarchy and focus (n-ary tree of workspaces)

#![allow(irrefutable_let_patterns)]

mod backend;
mod config;
mod handlers;
mod input;
mod state;
mod tree;

use smithay::reexports::calloop::EventLoop;
use smithay::reexports::wayland_server::Display;

use anyhow::Result;
use tracing::info;
use tracing_subscriber::{fmt, prelude::*, EnvFilter};

pub use state::Hayashi;

fn main() -> Result<()> {
    // Initialize logging
    tracing_subscriber::registry()
        .with(fmt::layer())
        .with(EnvFilter::from_default_env().add_directive("hayashi=debug".parse()?))
        .init();

    info!("🌲 Hayashi starting...");

    // Create the calloop event loop
    let mut event_loop: EventLoop<Hayashi> = EventLoop::try_new()?;

    // Create the Wayland display
    let display: Display<Hayashi> = Display::new()?;

    // Initialize compositor state
    let mut state = Hayashi::new(&mut event_loop, display);

    // Initialize the winit backend (opens a window for development)
    backend::winit::init_winit(&mut event_loop, &mut state)
        .expect("Failed to initialize winit backend");

    // Set WAYLAND_DISPLAY so child processes connect to Hayashi
    std::env::set_var("WAYLAND_DISPLAY", &state.socket_name);

    info!("🌲 Hayashi compositor running");

    // Spawn a test client
    spawn_client();

    // Run the event loop
    event_loop.run(None, &mut state, move |_| {
        // Hayashi is running
    })?;

    Ok(())
}

fn spawn_client() {
    let mut args = std::env::args().skip(1);
    let flag = args.next();
    let arg = args.next();

    match (flag.as_deref(), arg) {
        (Some("-c") | Some("--command"), Some(command)) => {
            info!("Spawning client: {}", command);
            std::process::Command::new(command).spawn().ok();
        }
        _ => {
            info!("No client specified; use -c <command> to launch one");
        }
    }
}
