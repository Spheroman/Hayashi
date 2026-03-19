//! Peek mode navigation
//!
//! Hayashi uses a "peek before commit" interaction model. Holding the Super key
//! enters peek mode, where navigation previews changes without applying them.
//! Releasing Super commits; pressing Escape cancels.

/// State during peek mode.
#[derive(Debug, Clone)]
pub struct PeekState {
    /// Where we started (to restore on cancel).
    pub original: usize,

    /// What we're currently previewing.
    pub current_peek: usize,

    /// The letter pressed to search.
    pub search_key: char,

    /// Where we've searched to (for continuing search upward).
    pub search_position: usize,
}

impl PeekState {
    pub fn new(from: usize, key: char) -> Self {
        Self {
            original: from,
            current_peek: from,
            search_key: key,
            search_position: from,
        }
    }

    /// Update to peek at a new target.
    pub fn peek_at(&mut self, target: usize, searched_from: usize) {
        self.current_peek = target;
        self.search_position = searched_from;
    }

    /// Change the search key (restart from original position).
    pub fn new_search(&mut self, key: char) {
        self.search_key = key;
        self.search_position = self.original;
    }
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

/// Navigation actions that can be triggered by input.
#[derive(Debug, Clone)]
pub enum NavAction {
    /// Enter peek mode and search for workspace with given name.
    StartPeek(char),

    /// Continue searching for same key (pressed again while peeking).
    ContinueSearch,

    /// Switch to searching for a different key.
    NewSearch(char),

    /// Cancel peek mode, return to original.
    Cancel,

    /// Commit the current peek as the new focus.
    Commit,

    /// Move focus in a direction within current workspace.
    FocusDirection(FocusDir),
}

/// Direction for focus movement within a workspace.
#[derive(Debug, Clone, Copy)]
pub enum FocusDir {
    Left,
    Right,
    Up,
    Down,
}

/// Result of handling a navigation action.
#[derive(Debug)]
pub enum NavResult {
    /// No change.
    None,

    /// Focus changed to this workspace.
    FocusChanged(usize),

    /// Created a new workspace at this index.
    Created(usize),

    /// Mode changed.
    ModeChanged(Mode),
}

// TODO: Implement the actual navigation logic
// This will be connected to the workspace tree's find_by_name
// and the compositor state in state.rs
