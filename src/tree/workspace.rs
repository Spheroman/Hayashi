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

    /// The currently active child workspace (shown when children share a zone).
    pub active_child: Option<usize>,
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
            active_child: None,
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

        // Set active_child if this is the first child
        if self.nodes[parent].active_child.is_none() {
            self.nodes[parent].active_child = Some(idx);
        }

        idx
    }

    /// Descend from a workspace to the leaf that is shown for it, following
    /// `active_child` (or the first child if none is set) at each level.
    pub fn leaf_under(&self, idx: usize) -> usize {
        let mut current = idx;
        loop {
            let children = self.children(current);
            if children.is_empty() {
                return current;
            }
            current = self.nodes[current]
                .active_child
                .filter(|c| children.contains(c))
                .unwrap_or(children[0]);
        }
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

    /// Get the children of a workspace.
    pub fn children(&self, idx: usize) -> Vec<usize> {
        match &self.nodes[idx].content {
            Content::Children(c) => c.clone(),
            _ => Vec::new(),
        }
    }

    /// Activate the path from root to the given workspace.
    /// Sets active_child at each level of the tree so the target becomes visible.
    pub fn activate_path(&mut self, target: usize) {
        let path = self.path_to(target);
        for i in 0..path.len().saturating_sub(1) {
            self.nodes[path[i]].active_child = Some(path[i + 1]);
        }
    }

    /// Find all visible leaf workspaces and their geometry.
    ///
    /// Walks the tree from the given workspace, following zone claims.
    /// At each level, children with unique zone claims are always visible.
    /// When multiple children claim the same zone, only the active child is shown.
    ///
    /// Each workspace receives one or more rects from its parent (multiple rects
    /// for L-shaped claims). The workspace's local_display subdivides single rects
    /// into zones for children; multi-rect inputs are treated as zones directly.
    pub fn visible_leaves(
        &self,
        ws_idx: usize,
        inherited_rects: &[Rect],
    ) -> Vec<(usize, Vec<Rect>)> {
        let ws = &self.nodes[ws_idx];

        match &ws.content {
            Content::Children(children) if !children.is_empty() => {
                // Compute zones available to children
                let zones: Vec<Rect> = if inherited_rects.len() == 1 {
                    // Single rect: subdivide using local display tree
                    ws.local_display.subdivide(inherited_rects[0])
                } else {
                    // Multiple rects (L-shape): each inherited rect is a zone
                    inherited_rects.to_vec()
                };

                // For each zone, determine which child wins it
                let zone_winners: Vec<Option<usize>> = zones
                    .iter()
                    .enumerate()
                    .map(|(zone_id, _)| {
                        let claimants: Vec<usize> = children
                            .iter()
                            .filter(|&&c| self.nodes[c].claims.contains(&ZoneId(zone_id)))
                            .copied()
                            .collect();

                        if claimants.len() == 1 {
                            Some(claimants[0])
                        } else if claimants.len() > 1 {
                            ws.active_child.filter(|ac| claimants.contains(ac))
                        } else {
                            None
                        }
                    })
                    .collect();

                // Group zone rects by winning child (preserves order for L-shapes)
                let mut child_rects: Vec<(usize, Vec<Rect>)> = Vec::new();
                for (zone_id, winner) in zone_winners.iter().enumerate() {
                    if let Some(child_idx) = winner {
                        if let Some(entry) =
                            child_rects.iter_mut().find(|(idx, _)| idx == child_idx)
                        {
                            entry.1.push(zones[zone_id]);
                        } else {
                            child_rects.push((*child_idx, vec![zones[zone_id]]));
                        }
                    }
                }

                // Recurse once per visible child with all its collected rects
                let mut results = Vec::new();
                for (child_idx, rects) in &child_rects {
                    results.extend(self.visible_leaves(*child_idx, rects));
                }

                results
            }
            _ => {
                // Leaf workspace — visible with all inherited rects
                vec![(ws_idx, inherited_rects.to_vec())]
            }
        }
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
    fn test_active_child_set_on_first_add() {
        let mut tree = WorkspaceTree::new();
        assert_eq!(tree.nodes[0].active_child, None);

        let ws_a = tree.add_child(0, Workspace::with_name('a'));
        assert_eq!(tree.nodes[0].active_child, Some(ws_a));

        // Second child doesn't change active_child
        let _ws_b = tree.add_child(0, Workspace::with_name('b'));
        assert_eq!(tree.nodes[0].active_child, Some(ws_a));
    }

    #[test]
    fn test_activate_path() {
        let mut tree = WorkspaceTree::new();
        let ws_p = tree.add_child(0, Workspace::with_name('p'));
        let ws_d = tree.add_child(0, Workspace::with_name('d'));
        let ws_n = tree.add_child(ws_p, Workspace::with_name('n'));

        // Activate path to ws_n: root -> p -> n
        tree.activate_path(ws_n);
        assert_eq!(tree.nodes[0].active_child, Some(ws_p));
        assert_eq!(tree.nodes[ws_p].active_child, Some(ws_n));

        // Activate path to ws_d: root -> d
        tree.activate_path(ws_d);
        assert_eq!(tree.nodes[0].active_child, Some(ws_d));
        // ws_p's active_child is still ws_n (preserved)
        assert_eq!(tree.nodes[ws_p].active_child, Some(ws_n));
    }

    #[test]
    fn test_visible_leaves_stacked() {
        use super::super::display::Rect;

        let mut tree = WorkspaceTree::new();
        let ws_a = tree.add_child(0, Workspace::with_name('a'));
        let _ws_b = tree.add_child(0, Workspace::with_name('b'));

        tree.activate_path(ws_a);

        let rect = Rect::new(0, 0, 1920, 1080);
        let visible = tree.visible_leaves(0, &[rect]);

        // Both claim zone 0, only active (ws_a) is visible
        assert_eq!(visible.len(), 1);
        assert_eq!(visible[0].0, ws_a);
        assert_eq!(visible[0].1, vec![rect]);
    }

    #[test]
    fn test_visible_leaves_split() {
        use super::super::display::{build_equal_hsplit, Rect, ZoneId};

        let mut tree = WorkspaceTree::new();
        let ws_a = tree.add_child(0, Workspace::with_name('a'));
        let ws_b = tree.add_child(0, Workspace::with_name('b'));

        // Split root's display tree into 2 zones
        tree.nodes[0].local_display.root = build_equal_hsplit(2);
        tree.nodes[ws_a].claims = vec![ZoneId(0)];
        tree.nodes[ws_b].claims = vec![ZoneId(1)];

        let rect = Rect::new(0, 0, 1920, 1080);
        let visible = tree.visible_leaves(0, &[rect]);

        // Both visible in their own zones
        assert_eq!(visible.len(), 2);
        assert_eq!(visible[0].0, ws_a);
        assert_eq!(visible[0].1, vec![Rect::new(0, 0, 960, 1080)]);
        assert_eq!(visible[1].0, ws_b);
        assert_eq!(visible[1].1, vec![Rect::new(960, 0, 960, 1080)]);
    }

    #[test]
    fn test_visible_leaves_nested() {
        use super::super::display::{build_equal_hsplit, Rect, ZoneId};

        let mut tree = WorkspaceTree::new();
        let ws_d = tree.add_child(0, Workspace::with_name('d'));
        let ws_p = tree.add_child(0, Workspace::with_name('p'));
        let ws_n = tree.add_child(ws_p, Workspace::with_name('n'));
        let _ws_f = tree.add_child(ws_p, Workspace::with_name('f'));

        // Split root: discord left, projects right
        tree.nodes[0].local_display.root = build_equal_hsplit(2);
        tree.nodes[ws_d].claims = vec![ZoneId(0)];
        tree.nodes[ws_p].claims = vec![ZoneId(1)];

        // Within projects, n and f are stacked (both claim zone 0)
        tree.activate_path(ws_n);

        let rect = Rect::new(0, 0, 1920, 1080);
        let visible = tree.visible_leaves(0, &[rect]);

        // Discord visible in left half, Node.js visible in right half
        assert_eq!(visible.len(), 2);
        assert_eq!(visible[0].0, ws_d);
        assert_eq!(visible[0].1, vec![Rect::new(0, 0, 960, 1080)]);
        assert_eq!(visible[1].0, ws_n);
        assert_eq!(visible[1].1, vec![Rect::new(960, 0, 960, 1080)]);
    }

    #[test]
    fn test_visible_leaves_l_shape() {
        use super::super::display::{DisplayNode, Rect, ZoneId};

        let mut tree = WorkspaceTree::new();
        let ws_d = tree.add_child(0, Workspace::with_name('d'));
        let ws_csr = tree.add_child(0, Workspace::with_name('c'));

        // Root has 2x2 grid: zones 0,1,2,3
        tree.nodes[0].local_display.root = DisplayNode::vsplit(
            0.5,
            DisplayNode::hsplit(0.5, DisplayNode::zone(0), DisplayNode::zone(1)),
            DisplayNode::hsplit(0.5, DisplayNode::zone(2), DisplayNode::zone(3)),
        );

        // Discord claims bottom-left only
        tree.nodes[ws_d].claims = vec![ZoneId(2)];
        // CSR claims L-shape: top-left, top-right, bottom-right
        tree.nodes[ws_csr].claims = vec![ZoneId(0), ZoneId(1), ZoneId(3)];

        let rect = Rect::new(0, 0, 1920, 1080);
        let visible = tree.visible_leaves(0, &[rect]);

        assert_eq!(visible.len(), 2);

        // CSR appears first (claims zone 0 which is processed first)
        // Gets three rects (zones 0, 1, 3: L-shape)
        assert_eq!(visible[0].0, ws_csr);
        assert_eq!(visible[0].1.len(), 3);
        assert_eq!(visible[0].1[0], Rect::new(0, 0, 960, 540));      // zone 0
        assert_eq!(visible[0].1[1], Rect::new(960, 0, 960, 540));     // zone 1
        assert_eq!(visible[0].1[2], Rect::new(960, 540, 960, 540));   // zone 3

        // Discord gets one rect (zone 2: bottom-left)
        assert_eq!(visible[1].0, ws_d);
        assert_eq!(visible[1].1, vec![Rect::new(0, 540, 960, 540)]);
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

    #[test]
    fn test_leaf_under() {
        let mut tree = WorkspaceTree::new();
        let ws_p = tree.add_child(0, Workspace::with_name('p'));
        let ws_n = tree.add_child(ws_p, Workspace::with_name('n'));
        let ws_f = tree.add_child(ws_p, Workspace::with_name('f'));

        assert_eq!(tree.leaf_under(ws_n), ws_n);
        assert_eq!(tree.leaf_under(0), ws_n);
        tree.activate_path(ws_f);
        assert_eq!(tree.leaf_under(0), ws_f);
        assert_eq!(tree.leaf_under(ws_p), ws_f);
    }
}
