//! Peek mode navigation
//!
//! Hayashi uses a "peek before commit" interaction model. Holding the Super key
//! enters peek mode, where navigation previews changes without applying them.
//! Releasing Super commits; pressing Escape cancels.
//!
//! The search itself lives in `Hayashi::peek_search` (state.rs); this module
//! holds the state it needs to continue a search and to undo it.

use smithay::desktop::Window;

use crate::tree::WorkspaceTree;

/// State during peek mode.
#[derive(Debug, Clone)]
pub struct PeekState {
    /// The workspace tree from before peeking, restored on cancel. Its
    /// `focus` is the origin every new search starts from.
    pub original_tree: WorkspaceTree,

    /// The window that had keyboard focus before peeking.
    pub original_window: Option<Window>,

    /// The letter being searched for (None until the first search).
    pub search_key: Option<char>,

    /// Where pressing the same letter again continues searching from.
    /// None once the search has run out of levels to climb.
    pub next_search: Option<usize>,

    /// Workspace created to preview "no match, create here". It only becomes
    /// real (and gets a launcher) on commit; searching on removes it.
    pub tentative: Option<usize>,
}

/// The current interaction mode.
#[derive(Debug, Clone)]
pub enum Mode {
    /// Normal operation - input goes to focused window.
    Normal,

    /// Peeking - previewing a workspace change.
    Peeking(PeekState),
}

impl Mode {
    pub fn is_peeking(&self) -> bool {
        matches!(self, Mode::Peeking(_))
    }
}

impl Default for Mode {
    fn default() -> Self {
        Mode::Normal
    }
}
