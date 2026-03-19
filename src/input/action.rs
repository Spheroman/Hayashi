//! Compositor actions triggered by keybindings.

/// Actions the compositor can perform in response to keybindings.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Action {
    /// Close the focused window.
    CloseWindow,

    /// Exit the compositor.
    Exit,

    /// Focus the window to the left.
    FocusLeft,

    /// Focus the window to the right.
    FocusRight,

    /// Focus the window above.
    FocusUp,

    /// Focus the window below.
    FocusDown,

    /// Focus the next sibling window.
    FocusNext,

    /// Focus the previous sibling window.
    FocusPrev,

    /// Switch to (or create) a workspace by name.
    SwitchWorkspace(char),

    /// Focus the parent workspace (move up the tree).
    FocusParent,

    /// Focus the first child workspace (move down the tree).
    FocusChild,

    /// Split parent's display tree horizontally, giving each child its own zone.
    SplitZoneH,

    /// Split parent's display tree vertically, giving each child its own zone.
    SplitZoneV,

    /// Merge parent's zones back to stacked (all children share zone 0).
    MergeZones,

    /// Move focused workspace to the adjacent zone on the left.
    MoveLeft,

    /// Move focused workspace to the adjacent zone on the right.
    MoveRight,

    /// Move focused workspace to the adjacent zone above.
    MoveUp,

    /// Move focused workspace to the adjacent zone below.
    MoveDown,
}
