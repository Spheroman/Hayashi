# Hayashi Default Keybindings

**Mod** = Super (Windows key)

## Workspace Navigation

All `Mod+letter` bindings are reserved for workspace navigation via peek mode.

| Keybind | Action |
|---------|--------|
| `Mod+<letter>` | Enter peek mode, search for workspace named `<letter>` |
| `<letter>` (while peeking) | Continue search upward for next match |
| `Escape` (while peeking) | Cancel, return to original workspace |
| `Release Mod` | Commit to peeked workspace |

**Workspace creation:**
- If no match is found on first press, creates workspace at current location
- If matches exist but search is exhausted (no more matches), creates at *origin* (where you started)
- New workspace opens the launcher to select an application
- **Creation context:** If focused on a window, creates as sibling. If focused on a container workspace, creates as child.

**Example:** Inside `flutter > terminal` (a window), pressing `Mod+b`:
- No match → create `b` as sibling to `terminal` (inside `flutter`)

**Example:** Inside `flutter` (container, no window focused), pressing `Mod+b`:
- No match → create `b` as child of `flutter`

**Example:** Inside `flutter`, pressing `Mod+d`:
- First match: `discord` (parent level) → peek it
- Press `d` again: no more matches → create `d` inside `flutter` (origin)

**Example:** Want `d` inside `discord`:
- `Mod+d` → peek `discord`
- Release Mod → commit to `discord`  
- `Mod+d` → no `d` here → create `d` inside `discord`

## Focus

| Keybind | Action |
|---------|--------|
| `Mod+Shift+h` | Focus left |
| `Mod+Shift+j` | Focus down |
| `Mod+Shift+k` | Focus up |
| `Mod+Shift+l` | Focus right |
| `Mod+Shift+Tab` | Focus previous sibling |
| `Mod+Tab` | Focus next sibling |
| `Mod+Shift+u` | Focus parent (move up the tree) |
| `Mod+Shift+d` | Focus first child (move down the tree) |

## Window Operations

| Keybind | Action |
|---------|--------|
| `Mod+Shift+q` | Close focused window |
| `Mod+Shift+f` | Toggle fullscreen |
| `Mod+Shift+c` | Toggle size constraint (centered/fill) |
| `Mod+Shift+s` | Set custom size constraint |

## Moving Windows (Within Zone Layout)

| Keybind | Action |
|---------|--------|
| `Mod+Ctrl+h` | Move window/workspace left |
| `Mod+Ctrl+j` | Move window/workspace down |
| `Mod+Ctrl+k` | Move window/workspace up |
| `Mod+Ctrl+l` | Move window/workspace right |

## Yank/Paste (Across Tree)

| Keybind | Action |
|---------|--------|
| `Mod+Ctrl+y` | Yank focused workspace (cut from tree) |
| `Mod+Ctrl+p` | Paste as child of current workspace |
| `Mod+Ctrl+w` | Unwrap: delete workspace, promote children to parent |

**Paste behavior:**
- Yanked workspace becomes a child of the current workspace
- If name collides (pasting `b` where `b` exists), pastes inside the existing `b`
- Yank buffer persists until next yank or paste

**Unwrap behavior:**
- Removes the current workspace from the tree
- All children (windows or nested workspaces) move up to the parent
- Useful for renaming: yank → create new name → paste → unwrap old name

## Display Tree (Zones)

| Keybind | Action |
|---------|--------|
| `Mod+Ctrl+s` | Split current zone horizontally |
| `Mod+Ctrl+v` | Split current zone vertically |
| `Mod+Ctrl+m` | Merge zone with neighbor |
| `Mod+Ctrl+c` | Claim adjacent zone (for L-shapes) |
| `Mod+Ctrl+x` | Release one claimed zone |

## Resizing

| Keybind | Action |
|---------|--------|
| `Mod+Ctrl+Shift+h` | Shrink from right |
| `Mod+Ctrl+Shift+j` | Grow downward |
| `Mod+Ctrl+Shift+k` | Shrink from bottom |
| `Mod+Ctrl+Shift+l` | Grow rightward |
| `Mod+Ctrl+Shift+r` | Reset zone ratios to equal |

## Session

| Keybind | Action |
|---------|--------|
| `Mod+Shift+r` | Reload configuration |
| `Mod+Shift+e` | Exit Hayashi |
| `Mod+Shift+p` | Save session |

## Notes

- **No `Mod+Return` for terminal**: Create a workspace for it instead
- **No application launcher bind**: Launcher appears when creating a new workspace
- **Workspace names are single characters**: Navigate with `Mod+<letter>`, search climbs the tree
- **Peek mode is visual**: See the target workspace before committing