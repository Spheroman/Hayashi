//! Display Tree - Geometry subdivision
//!
//! A binary tree that recursively subdivides screen space into rectangular zones.
//! Each workspace maintains its own display tree for its claimed zones, enabling
//! different layouts per workspace.

/// Unique identifier for a zone in the display tree.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct ZoneId(pub usize);

/// A rectangle in screen coordinates.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct Rect {
    pub x: i32,
    pub y: i32,
    pub width: u32,
    pub height: u32,
}

impl Rect {
    pub fn new(x: i32, y: i32, width: u32, height: u32) -> Self {
        Self { x, y, width, height }
    }

    /// Center a smaller rect within this rect.
    pub fn center(&self, width: u32, height: u32) -> Rect {
        Rect {
            x: self.x + (self.width.saturating_sub(width) / 2) as i32,
            y: self.y + (self.height.saturating_sub(height) / 2) as i32,
            width: width.min(self.width),
            height: height.min(self.height),
        }
    }
}

/// Split direction for display nodes.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Direction {
    Horizontal, // left | right
    Vertical,   // top / bottom
}

/// A node in the display tree.
///
/// The tree recursively subdivides space. Leaf nodes are zones that can be
/// claimed by workspaces.
#[derive(Debug, Clone)]
pub enum DisplayNode {
    /// A split node dividing space between two children.
    Split {
        direction: Direction,
        /// Ratio of space given to the left/top child (0.0 to 1.0)
        ratio: f32,
        left: Box<DisplayNode>,
        right: Box<DisplayNode>,
    },
    /// A leaf node representing a claimable zone.
    Zone(ZoneId),
}

impl DisplayNode {
    /// Create a single zone (no splits).
    pub fn zone(id: usize) -> Self {
        DisplayNode::Zone(ZoneId(id))
    }

    /// Create a horizontal split (left | right).
    pub fn hsplit(ratio: f32, left: DisplayNode, right: DisplayNode) -> Self {
        DisplayNode::Split {
            direction: Direction::Horizontal,
            ratio,
            left: Box::new(left),
            right: Box::new(right),
        }
    }

    /// Create a vertical split (top / bottom).
    pub fn vsplit(ratio: f32, top: DisplayNode, bottom: DisplayNode) -> Self {
        DisplayNode::Split {
            direction: Direction::Vertical,
            ratio,
            left: Box::new(top),
            right: Box::new(bottom),
        }
    }

    /// Subdivide a rectangle according to this tree, returning zone rects.
    ///
    /// Returns a Vec where index corresponds to ZoneId.
    pub fn subdivide(&self, rect: Rect) -> Vec<Rect> {
        let mut zones = Vec::new();
        self.subdivide_into(rect, &mut zones);
        zones
    }

    fn subdivide_into(&self, rect: Rect, zones: &mut Vec<Rect>) {
        match self {
            DisplayNode::Zone(ZoneId(id)) => {
                // Ensure vec is large enough
                if zones.len() <= *id {
                    zones.resize(*id + 1, Rect::new(0, 0, 0, 0));
                }
                zones[*id] = rect;
            }
            DisplayNode::Split { direction, ratio, left, right } => {
                let (left_rect, right_rect) = match direction {
                    Direction::Horizontal => {
                        let left_width = (rect.width as f32 * ratio) as u32;
                        let right_width = rect.width - left_width;
                        (
                            Rect::new(rect.x, rect.y, left_width, rect.height),
                            Rect::new(rect.x + left_width as i32, rect.y, right_width, rect.height),
                        )
                    }
                    Direction::Vertical => {
                        let top_height = (rect.height as f32 * ratio) as u32;
                        let bottom_height = rect.height - top_height;
                        (
                            Rect::new(rect.x, rect.y, rect.width, top_height),
                            Rect::new(rect.x, rect.y + top_height as i32, rect.width, bottom_height),
                        )
                    }
                };
                left.subdivide_into(left_rect, zones);
                right.subdivide_into(right_rect, zones);
            }
        }
    }

    /// Count the number of zones in this tree.
    pub fn zone_count(&self) -> usize {
        match self {
            DisplayNode::Zone(_) => 1,
            DisplayNode::Split { left, right, .. } => left.zone_count() + right.zone_count(),
        }
    }
}

/// A display tree with a next zone ID counter.
#[derive(Debug, Clone)]
pub struct DisplayTree {
    pub root: DisplayNode,
    next_zone_id: usize,
}

impl DisplayTree {
    /// Create a new display tree with a single zone.
    pub fn new() -> Self {
        Self {
            root: DisplayNode::zone(0),
            next_zone_id: 1,
        }
    }

    /// Get the next available zone ID.
    pub fn next_zone_id(&mut self) -> ZoneId {
        let id = ZoneId(self.next_zone_id);
        self.next_zone_id += 1;
        id
    }

    /// Subdivide the given rect according to this tree.
    pub fn subdivide(&self, rect: Rect) -> Vec<Rect> {
        self.root.subdivide(rect)
    }
}

impl Default for DisplayTree {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_single_zone() {
        let tree = DisplayTree::new();
        let rect = Rect::new(0, 0, 1920, 1080);
        let zones = tree.subdivide(rect);

        assert_eq!(zones.len(), 1);
        assert_eq!(zones[0], rect);
    }

    #[test]
    fn test_horizontal_split() {
        let tree = DisplayNode::hsplit(
            0.5,
            DisplayNode::zone(0),
            DisplayNode::zone(1),
        );
        let rect = Rect::new(0, 0, 1920, 1080);
        let zones = tree.subdivide(rect);

        assert_eq!(zones.len(), 2);
        assert_eq!(zones[0], Rect::new(0, 0, 960, 1080));
        assert_eq!(zones[1], Rect::new(960, 0, 960, 1080));
    }

    #[test]
    fn test_quad_split() {
        // Create a 2x2 grid like in the spec:
        // ┌───┬───┐
        // │ 0 │ 1 │
        // ├───┼───┤
        // │ 2 │ 3 │
        // └───┴───┘
        let tree = DisplayNode::vsplit(
            0.5,
            DisplayNode::hsplit(0.5, DisplayNode::zone(0), DisplayNode::zone(1)),
            DisplayNode::hsplit(0.5, DisplayNode::zone(2), DisplayNode::zone(3)),
        );
        let rect = Rect::new(0, 0, 1920, 1080);
        let zones = tree.subdivide(rect);

        assert_eq!(zones.len(), 4);
        assert_eq!(zones[0], Rect::new(0, 0, 960, 540));
        assert_eq!(zones[1], Rect::new(960, 0, 960, 540));
        assert_eq!(zones[2], Rect::new(0, 540, 960, 540));
        assert_eq!(zones[3], Rect::new(960, 540, 960, 540));
    }
}
