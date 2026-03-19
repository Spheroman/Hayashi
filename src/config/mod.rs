//! Configuration system
//!
//! Handles workspace templates, window rules, and keybindings.

use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// Main configuration structure.
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct Config {
    /// Keybinding configuration.
    #[serde(default)]
    pub keybinds: KeybindConfig,

    /// Workspace templates for quick setup.
    #[serde(default)]
    pub templates: HashMap<String, WorkspaceTemplate>,

    /// Window rules for automatic placement.
    #[serde(default)]
    pub window_rules: Vec<WindowRule>,

    /// Application launcher command.
    #[serde(default = "default_launcher")]
    pub launcher: String,
}

fn default_launcher() -> String {
    "fuzzel".to_string()
}

/// Keybinding configuration.
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct KeybindConfig {
    /// The modifier key for workspace navigation (default: Super).
    #[serde(default = "default_mod")]
    pub mod_key: String,

    /// Custom keybindings.
    #[serde(default)]
    pub bindings: HashMap<String, String>,
}

fn default_mod() -> String {
    "Super".to_string()
}

/// A workspace template for auto-spawning with specific layouts.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WorkspaceTemplate {
    /// The name/key for this workspace.
    pub name: char,

    /// Human-readable label.
    pub label: Option<String>,

    /// Child workspaces to create.
    #[serde(default)]
    pub children: Vec<WorkspaceTemplate>,

    /// Application to launch in this workspace.
    pub app: Option<String>,

    /// Display layout (simplified for config).
    #[serde(default)]
    pub layout: LayoutConfig,
}

/// Simplified layout configuration for the config file.
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct LayoutConfig {
    /// Split direction.
    pub direction: Option<String>, // "horizontal" or "vertical"

    /// Split ratio (0.0 to 1.0).
    pub ratio: Option<f32>,
}

/// A window rule for automatic workspace assignment.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WindowRule {
    /// Match by app_id (Wayland) or class (X11).
    pub app_id: Option<String>,

    /// Match by window title (regex).
    pub title: Option<String>,

    /// Target workspace path (e.g., "d" or "p>c").
    pub workspace: String,

    /// Optional size constraint.
    pub size: Option<(u32, u32)>,
}

impl Config {
    /// Load config from file or return default.
    pub fn load() -> Self {
        let config_path = dirs::config_dir()
            .map(|p| p.join("hayashi/config.toml"))
            .unwrap_or_default();

        if config_path.exists() {
            match std::fs::read_to_string(&config_path) {
                Ok(contents) => match toml::from_str(&contents) {
                    Ok(config) => return config,
                    Err(e) => {
                        tracing::warn!("Failed to parse config: {e}");
                    }
                },
                Err(e) => {
                    tracing::warn!("Failed to read config: {e}");
                }
            }
        }

        Self::default()
    }
}

// Example config.toml:
//
// launcher = "fuzzel"
//
// [keybinds]
// mod_key = "Super"
//
// [keybinds.bindings]
// "Super+Return" = "spawn:foot"
// "Super+d" = "launcher"
//
// [[window_rules]]
// app_id = "discord"
// workspace = "d"
//
// [[window_rules]]
// app_id = "spotify"
// workspace = "m"
//
// [templates.csr]
// name = 'c'
// label = "CSR Project"
// children = [
//   { name = 't', app = "foot" },
//   { name = 'e', app = "code" },
//   { name = 'b', app = "firefox" },
// ]
