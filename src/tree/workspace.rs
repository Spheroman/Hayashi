//! Workspace Tree - Hierarchy and focus
//!
//! An n-ary tree where each node is a workspace. Workspaces claim zones from
//! their parent's display tree and can subdivide those zones for their children.
//! Windows are leaf nodes.

use super::{DisplayTree, Rect, ZoneId};

/// The content of a workspace - either children or a window.
#[derive(Debug, Clone)]
pub enum Content {
    /// This workspace contains child workspaces.
    Children(Vec<usize>), // indices into WorkspaceTree.nodes
    /// This workspace contains a window.
    Window(WindowId),
    /// This workspace is empty (newly created).
    Empty,
}

/// Placeholder for window identification.
/// Will be replaced with actual Wayland surface reference.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct WindowId(pub u64);

/// Size constraint for a window (enables "floating" behavior without a separate mode).
#[derive(Debug, Clone, Copy)]
pub struct SizeConstraint {
    pub width: u32,
    pub height: u32,
}

/// A workspace node in the hierarchy.
#[derive(Debug, Clone)]
pub struct Workspace {
    /// Single-character name for quick navigation (e.g., 'c' for Chrome).
    pub name: Option<char>,

    /// Human-readable label (e.g., "Chrome", "CSR Project").
    pub label: Option<String>,

    /// Zone IDs claimed from parent's display tree.
    /// Multiple claims enable L-shaped layouts.
    pub claims: Vec<ZoneId>,

    /// Local display tree for subdividing claimed zones.
    pub local_display: DisplayTree,

    /// The content of this workspace.
    pub content: Content,

    /// Parent workspace index (None for root).
    pub parent: Option<usize>,

    /// Optional size constraint (for "floating" windows).
    pub size_constraint: Option<SizeConstraint>,
}

impl Workspace {
    /// Create a new empty workspace.
    pub fn new() -> Self {
        Self {
            name: None,
            label: None,
            claims: vec![ZoneId(0)], // Claim the first zone by default
            local_display: DisplayTree::new(),
            content: Content::Empty,
            parent: None,
            size_constraint: None,
        }
    }

    /// Create a workspace with a name.
    pub fn with_name(name: char) -> Self {
        Self {
            name: Some(name),
            ..Self::new()
        }
    }

    /// Set the zone claims for this workspace.
    pub fn with_claims(mut self, claims: Vec<ZoneId>) -> Self {
        self.claims = claims;
        self
    }
}

impl Default for Workspace {
    fn default() -> Self {
        Self::new()
    }
}

/// The workspace tree - an arena of workspace nodes.
#[derive(Debug)]
pub struct WorkspaceTree {
    /// All workspaces stored in a flat vec (arena allocation).
    pub nodes: Vec<Workspace>,

    /// Index of the root workspace.
    pub root: usize,

    /// Currently focused workspace.
    pub focus: usize,
}

impl WorkspaceTree {
    /// Create a new workspace tree with a root workspace.
    pub fn new() -> Self {
        let root = Workspace::new();
        Self {
            nodes: vec![root],
            root: 0,
            focus: 0,
        }
    }

    /// Add a child workspace to a parent.
    /// Returns the index of the new workspace.
    pub fn add_child(&mut self, parent: usize, workspace: Workspace) -> usize {
        let idx = self.nodes.len();
        let mut ws = workspace;
        ws.parent = Some(parent);
        self.nodes.push(ws);

        // Update parent's content
        match &mut self.nodes[parent].content {
            Content::Children(children) => children.push(idx),
            Content::Empty => self.nodes[parent].content = Content::Children(vec![idx]),
            Content::Window(_) => {
                // Converting a window workspace to have children - unusual but allowed
                self.nodes[parent].content = Content::Children(vec![idx]);
            }
        }

        idx
    }

    /// Find a workspace by name, searching upward from the given starting point.
    /// Returns the first match found.
    pub fn find_by_name(&self, name: char, start: usize) -> Option<usize> {
        let mut current = Some(start);

        while let Some(idx) = current {
            // Search children of current workspace
            if let Content::Children(children) = &self.nodes[idx].content {
                for &child_idx in children {
                    if self.nodes[child_idx].name == Some(name) {
                        return Some(child_idx);
                    }
                }
            }

            // Move up to parent
            current = self.nodes[idx].parent;
        }

        None
    }

    /// Get the path from root to a workspace.
    pub fn path_to(&self, idx: usize) -> Vec<usize> {
        let mut path = Vec::new();
        let mut current = Some(idx);

        while let Some(i) = current {
            path.push(i);
            current = self.nodes[i].parent;
        }

        path.reverse();
        path
    }

    /// Get the parent of a workspace node.
    pub fn parent(&self, idx: usize) -> Option<usize> {
        self.nodes[idx].parent
    }

    /// Get the first child of a workspace node.
    pub fn first_child(&self, idx: usize) -> Option<usize> {
        match &self.nodes[idx].content {
            Content::Children(children) => children.first().copied(),
            _ => None,
        }
    }

    /// Get the name of a workspace node.
    pub fn name(&self, idx: usize) -> Option<char> {
        self.nodes[idx].name
    }

    /// Format the full path from root to a workspace as a string.
    /// e.g. "root > a > b"
    pub fn path_string(&self, idx: usize) -> String {
        self.path_to(idx)
            .iter()
            .map(|&i| {
                self.nodes[i]
                    .name
                    .map(|c| c.to_string())
                    .unwrap_or_else(|| "root".to_string())
            })
            .collect::<Vec<_>>()
            .join(" > ")
    }

    /// Compute the rectangles for a workspace given inherited geometry.
    pub fn compute_rects(&self, idx: usize, inherited: &[Rect]) -> Vec<Rect> {
        let ws = &self.nodes[idx];

        // Gather claimed rects from inherited geometry
        let claimed: Vec<Rect> = ws
            .claims
            .iter()
            .filter_map(|&ZoneId(id)| inherited.get(id).copied())
            .collect();

        // If only one claimed rect, use local display tree to subdivide
        if claimed.len() == 1 {
            ws.local_display.subdivide(claimed[0])
        } else {
            // Multiple claims (L-shape): for now, just return them as-is
            // TODO: More sophisticated merging for L-shapes
            claimed
        }
    }
}

impl Default for WorkspaceTree {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_workspace_creation() {
        let tree = WorkspaceTree::new();
        assert_eq!(tree.nodes.len(), 1);
        assert_eq!(tree.root, 0);
        assert_eq!(tree.focus, 0);
    }

    #[test]
    fn test_add_children() {
        let mut tree = WorkspaceTree::new();

        let discord = tree.add_child(0, Workspace::with_name('d'));
        let projects = tree.add_child(0, Workspace::with_name('p'));

        assert_eq!(tree.nodes.len(), 3);
        assert_eq!(tree.nodes[discord].name, Some('d'));
        assert_eq!(tree.nodes[projects].name, Some('p'));

        if let Content::Children(children) = &tree.nodes[0].content {
            assert_eq!(children, &vec![discord, projects]);
        } else {
            panic!("Root should have children");
        }
    }

    #[test]
    fn test_find_by_name() {
        let mut tree = WorkspaceTree::new();

        let discord = tree.add_child(0, Workspace::with_name('d'));
        let projects = tree.add_child(0, Workspace::with_name('p'));
        let csr = tree.add_child(projects, Workspace::with_name('c'));

        // Find from root level
        assert_eq!(tree.find_by_name('d', 0), Some(discord));
        assert_eq!(tree.find_by_name('p', 0), Some(projects));

        // Find from within projects
        assert_eq!(tree.find_by_name('c', projects), Some(csr));

        // Find from csr should search up and find siblings
        assert_eq!(tree.find_by_name('d', csr), Some(discord));
    }

    #[test]
    fn test_parent_and_first_child() {
        let mut tree = WorkspaceTree::new();

        let ws_a = tree.add_child(0, Workspace::with_name('a'));
        let ws_b = tree.add_child(0, Workspace::with_name('b'));

        assert_eq!(tree.parent(ws_a), Some(0));
        assert_eq!(tree.parent(ws_b), Some(0));
        assert_eq!(tree.parent(0), None);
        assert_eq!(tree.first_child(0), Some(ws_a));
        assert_eq!(tree.first_child(ws_a), None);
    }

    #[test]
    fn test_workspace_name() {
        let mut tree = WorkspaceTree::new();

        let ws_a = tree.add_child(0, Workspace::with_name('a'));

        assert_eq!(tree.name(0), None); // root has no name
        assert_eq!(tree.name(ws_a), Some('a'));
    }

    #[test]
    fn test_find_by_name_creates_sibling_context() {
        // Simulates the workspace switching flow:
        // When in 'a' and searching for 'b', find_by_name searches up to root
        let mut tree = WorkspaceTree::new();

        let ws_a = tree.add_child(0, Workspace::with_name('a'));
        let ws_b = tree.add_child(0, Workspace::with_name('b'));

        // From ws_a, can find sibling ws_b by searching upward
        assert_eq!(tree.find_by_name('b', ws_a), Some(ws_b));

        // From ws_b, can find sibling ws_a
        assert_eq!(tree.find_by_name('a', ws_b), Some(ws_a));

        // Searching for nonexistent returns None
        assert_eq!(tree.find_by_name('z', ws_a), None);
    }
}
