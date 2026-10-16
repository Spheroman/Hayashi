# Hayashi shell

A Material 3 shell for Hayashi, written for [Quickshell](https://quickshell.org). It runs on Hyprland today and will move to Hayashi once the IPC in issue #5 exists.

## The design

- A frame borders the screen: a left bar (workspaces and status) and thin borders on the other edges.
- The wallpaper and windows form a card inside the frame. The shell is everything windows don't cover. The wallpaper only shows in gaps between windows of the same workspace, and on empty workspaces.
- `Super+Esc` slides the card off to the right, revealing panels underneath: quick settings, volume and brightness, media, and session controls. The panels don't animate; only the card moves.
- Corners are concentric. The window radius is the card radius minus the gap.
- Nothing is transparent. Apps and the shell use opaque Material surfaces derived from one seed hue.

Tuned values live in `config/Tokens.qml` and colors in `config/Theme.qml`.

## Layout

| Path | What's there |
|---|---|
| `shell.qml` | Entry point: one wallpaper, frame and panel overlay per screen, plus the `panels` IPC target |
| `config/` | Tokens (sizes, motion, fonts) and Theme (color roles) |
| `services/Compositor.qml` | The only file that talks to the compositor. Hyprland today; a Hayashi backend replaces it |
| `services/ShellState.qml` | Shared UI state |
| `modules/` | Frame, bar, wallpaper and the panel overlay |
| `modules/panels/` | The panel view's contents |
| `widgets/` | Small shared pieces (Icon, Label) |

## Using it

With Nix, import `homeManagerModules.hayashi-shell` from this flake and set `programs.hayashi-shell.enable = true`. To edit it live, set `programs.hayashi-shell.devPath` to your checkout of this directory. Then start `qs` from your compositor and bind `qs ipc call panels toggle` to `Super+Esc`.

Without Nix, link this directory to `~/.config/quickshell` and install Quickshell 0.3 or newer, Material Symbols Rounded, Space Grotesk and SpaceMono Nerd Font.
