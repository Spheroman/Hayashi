//! Input handling and navigation
//!
//! Implements the "peek before commit" interaction model.

mod action;
mod navigation;
mod process;

pub use action::Action;
pub use navigation::{Mode, PeekState};

/// Key modifiers.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Modifiers {
    pub ctrl: bool,
    pub alt: bool,
    pub shift: bool,
    pub super_key: bool,
}

impl Modifiers {
    pub fn none() -> Self {
        Self {
            ctrl: false,
            alt: false,
            shift: false,
            super_key: false,
        }
    }
}
