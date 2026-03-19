# Hayashi (林) - Technical Specification v0.1

*A Wayland Compositor with Nested Workspaces*

January 2026

## Overview

Hayashi is a Wayland compositor built on Smithay that implements nested, hierarchical workspaces. The name (林, Japanese for "grove") reflects its core architecture: two interconnected trees that manage display geometry and workspace hierarchy separately.

Unlike traditional tiling window managers that offer flat workspace lists (workspace 1-10), Hayashi allows workspaces to contain other workspaces, enabling project-based organization. A "CSR" project workspace might contain terminal, browser, and editor sub-workspaces. Switching projects changes everything; switching within a project preserves context.

## Design Philosophy

### Core Principles

- **Workspaces all the way down**: Everything is a workspace. Windows are leaf workspaces that render a surface instead of containing children.
- **Two trees, separate concerns**: The display tree handles geometry; the workspace tree handles hierarchy and focus. They communicate through zone IDs.
- **No floating mode**: Windows can have size constraints and center within their allocated space. This handles "floating" use cases without special modes.
- **Peek before commit**: Navigation previews changes before applying them, allowing cancellation.

## Architecture

### The Two Trees

Hayashi's architecture centers on two distinct tree structures that work together:

#### Display Tree (Geometry)

A binary tree that recursively subdivides screen space into rectangular zones. Each workspace maintains its own display tree for its claimed zones, enabling different layouts per workspace.

```rust
enum DisplayNode {
    Split {
        direction: Direction,
        ratio: f32,
        left: Box<DisplayNode>,
        right: Box<DisplayNode>,
    },
    Zone(ZoneId),
}
```

#### Workspace Tree (Hierarchy)

An n-ary tree where each node is a workspace. Workspaces claim zones from their parent's display tree and can subdivide those zones for their children. Windows are leaf nodes.

```rust
struct Workspace {
    name: Option<char>,
    claims: Vec<ZoneId>,
    local_display: DisplayNode,
    children: Vec<Workspace>,
    content: Content,
}

enum Content {
    Children(Vec<Workspace>),
    Window(WlSurface),
}
```

### Zone Claims and L-Shapes

Children claim one or more zones from the parent's display tree. This enables non-rectangular layouts:

```
Parent display tree: 4 zones
┌───┬───┐
│ 0 │ 1 │
├───┼───┤
│ 2 │ 3 │
└───┴───┘

Children:
  - Discord: claims [2]       (bottom-left)
  - Projects: claims [0,1,3]  (L-shape)
```

Each workspace inherits zones from its parent and can subdivide them independently. The CSR workspace might split its L-shaped region differently than the Flutter workspace, even though both claim the same parent zones.

### Data Flow

```rust
fn render(ws: &Workspace, inherited_rects: Vec<Rect>) {
    // Subdivide inherited geometry using local display tree
    let my_rects = ws.local_display.subdivide(inherited_rects);
    
    // Pass appropriate rects to each child based on claims
    for child in &ws.children {
        let child_rects: Vec<Rect> = child.claims.iter()
            .map(|&i| my_rects[i])
            .collect();
        render(child, child_rects);
    }
}
```

## Navigation Model

### Peek Mode

Hayashi uses a "peek before commit" interaction model. Holding the Super key enters peek mode, where navigation previews changes without applying them. Releasing Super commits; pressing Escape cancels.

```rust
struct PeekState {
    original: NodeId,        // where we started
    current_peek: NodeId,    // what we're previewing
    search_key: char,        // the letter pressed
    search_position: NodeId, // where we've searched to
}

enum Mode {
    Normal,
    Peeking(PeekState),
}
```

### Search Behavior

Pressing a letter while peeking searches upward through the workspace tree for a matching name:

| Input | Action |
|-------|--------|
| Super+d | Enter peek mode, search from current node, peek first match |
| d (while peeking) | Continue search upward, peek next match |
| Different letter | Restart search from original position with new key |
| Escape | Cancel, return to original, exit peek mode |
| Release Super | Commit current peek as new focus |

### Search-or-Create

If no matching workspace is found, Hayashi creates a new workspace at the current tree level with the searched name and spawns the configured launcher (fuzzel/rofi/wofi) to select an application.

## Window Management

### Size Constraints

Instead of a separate floating mode, windows can have optional size constraints. If a window's constraint is smaller than its allocated space, it centers within that space:

```rust
struct Window {
    client: WlSurface,
    size_constraint: Option<(u32, u32)>,
}

fn compute_window_geometry(allocated: Rect, constraint: Option<(u32, u32)>) -> Rect {
    match constraint {
        None => allocated,
        Some((w, h)) => Rect {
            x: allocated.x + (allocated.width - w) / 2,
            y: allocated.y + (allocated.height - h) / 2,
            width: w,
            height: h,
        },
    }
}
```

This enables use cases like testing mobile viewport sizes in a browser without introducing a separate floating window mode.

### Sticky Windows

Sticky behavior emerges from the tree structure. If Discord is a sibling workspace to a "projects" container, switching between CSR/Flutter/Games within projects leaves Discord untouched:

```
Monitor
├── Discord (claims bottom-left zone)
└── Projects (claims remaining zones)
    ├── CSR
    ├── Flutter
    └── Games
```

## External Integration

Hayashi integrates with the existing Wayland ecosystem through standard protocols and standalone tools:

| Function | Integration |
|----------|-------------|
| Bar | Waybar, eww, yambar via zwlr_layer_shell protocol |
| Launcher | fuzzel, wofi, tofi, bemenu (configurable) |
| Notifications | mako, fnott via freedesktop notification protocol |
| Wallpaper | swaybg, hyprpaper, or internal rendering |
| Screen lock | swaylock via ext-session-lock-v1 protocol |
| Screenshots | grim/slurp via wlr-screencopy protocol |
| Gaming | gamescope as nested compositor for Proton/XWayland games |
| Portals | xdg-desktop-portal-wlr for sandboxed apps |

## Configuration

### Workspace Templates

Pre-defined workspace structures that auto-spawn with specific layouts and applications. Creating a new "csr" workspace could automatically set up terminal, editor, and browser sub-workspaces.

### Window Rules

Automatic workspace assignment based on application ID. Spotify always goes to workspace 'm' (music), Discord to 'd', Steam games launch inside the 'g' workspace nested in gamescope.

### Session Persistence

Save the entire tree structure to disk and restore on boot. All projects, window positions, zone claims, and nesting hierarchy preserved exactly as left.

## Technical Stack

- **Language**: Rust
- **Compositor library**: Smithay
- **Display server**: Wayland
- **Reference starting point**: smallvil (Smithay's minimal compositor)
- **Required protocols**: zwlr_layer_shell, pointer-constraints, relative-pointer, ext-session-lock-v1, wlr-screencopy

## Development Milestones

1. **Display one window** — Basic Smithay/EGL/DRM setup
2. **Two windows side by side** — Basic display tree with one split
3. **Keyboard focus** — Input handling and focus tracking
4. **Basic workspace tree** — Multiple workspaces, switching
5. **Nested workspaces** — Workspace hierarchy, zone claims
6. **Peek mode navigation** — Preview-before-commit interaction
7. **Layer shell support** — Bars, launchers, notifications
8. **Configuration system** — Templates, rules, keybinds
9. **Session persistence** — Save/restore tree state
10. **Default rice** — Bundled waybar config, theme, documentation

## Future Features

- **Workspace peeking**: Temporarily overlay another workspace at reduced opacity for quick reference
- **Named bookmarks**: Direct keybinds to specific nodes regardless of tree depth
- **Scratchpad**: Hidden workspace toggleable over any context
- **Multi-monitor L-shapes**: Workspaces spanning non-contiguous regions across monitors

---

*Hayashi: Two trees. Nested workspaces. Project-based tiling for Wayland.*
