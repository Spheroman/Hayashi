# Hayashi (林)

A Wayland compositor with nested hierarchical workspaces.

**Status:** Early development (pre-milestone 1)

## The Idea

Unlike traditional tiling window managers with flat workspace lists (1-10), Hayashi allows workspaces to contain other workspaces. A "CSR" project workspace might contain terminal, browser, and editor sub-workspaces. Switching projects changes everything; switching within a project preserves context.

```
Monitor
├── Discord (claims bottom-left zone)
└── Projects (claims remaining zones)
    ├── CSR
    │   ├── t (terminal)
    │   ├── e (editor)
    │   └── b (browser)
    ├── Flutter
    └── Games
```

## Key Features (Planned)

- **Nested workspaces**: Workspaces all the way down. Windows are leaf workspaces.
- **Two-tree architecture**: Display tree (geometry) and workspace tree (hierarchy) are separate.
- **L-shaped layouts**: Workspaces can claim multiple zones for non-rectangular regions.
- **Peek before commit**: Preview workspace changes before applying them.
- **No floating mode**: Size constraints enable "floating" behavior within the unified model.

## Building

```bash
cargo build
```

## Development

See `docs/SPEC.md` for the full technical specification.

### Milestones

1. **Display one window** — Basic Smithay/EGL setup *(start here!)*
2. **Two windows side by side** — Basic display tree with one split
3. **Keyboard focus** — Input handling and focus tracking
4. **Basic workspace tree** — Multiple workspaces, switching
5. **Nested workspaces** — Workspace hierarchy, zone claims
6. **Peek mode navigation** — Preview-before-commit interaction
7. **Layer shell support** — Bars, launchers, notifications
8. **Configuration system** — Templates, rules, keybinds
9. **Session persistence** — Save/restore tree state
10. **Default rice** — Bundled waybar config, theme, documentation

### Getting Started

The `src/backend/mod.rs` file has guidance for milestone 1. Start by studying [smallvil](https://github.com/Smithay/smithay/tree/master/smallvil), Smithay's minimal example compositor.

## License

MIT
