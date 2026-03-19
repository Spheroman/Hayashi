//! Main compositor state
//!
//! This holds the two trees and manages their interaction.

use crate::tree::{DisplayTree, WorkspaceTree};
use crate::input::Mode;

/// The main compositor state.
///
/// Hayashi's architecture centers on two distinct tree structures:
/// - `display_tree`: Binary tree that subdivides screen space into zones
/// - `workspace_tree`: N-ary tree of workspaces that claim zones
pub struct Hayashi {
    /// The display tree (geometry) - one per output
    pub display_trees: Vec<DisplayTree>,

    /// The workspace tree (hierarchy)
    pub workspace_tree: WorkspaceTree,

    /// Current interaction mode (Normal or Peeking)
    pub mode: Mode,

    /// Currently focused workspace node
    pub focus: Option<usize>,
}

impl Hayashi {
    pub fn new() -> Self {
        Self {
            display_trees: Vec::new(),
            workspace_tree: WorkspaceTree::new(),
            mode: Mode::Normal,
            focus: None,
        }
    }
}

impl Default for Hayashi {
    fn default() -> Self {
        Self::new()
    }
}
