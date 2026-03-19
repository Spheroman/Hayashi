//! The two trees at the heart of Hayashi.
//!
//! - `display`: Binary tree for geometry subdivision
//! - `workspace`: N-ary tree for workspace hierarchy

mod display;
mod workspace;

pub use display::{build_equal_hsplit, build_equal_vsplit, Direction, DisplayNode, DisplayTree, Rect, ZoneId};
pub use workspace::{Content, Workspace, WorkspaceTree};
