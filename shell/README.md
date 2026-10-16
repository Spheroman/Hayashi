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

With Nix, import two modules from this flake and enable both:

- `homeManagerModules.hayashi-shell` (`programs.hayashi-shell.enable = true`) installs the shell, its fonts and the `hayashi-shell` command.
- `nixosModules.hayashi-shell` (`programs.hayashi-shell.enable = true`) adds the `hayashi-shell` PAM service the lock screen signs in with.

Then, from your compositor:

- start `hayashi-shell` at login
- bind `hayashi-shell msg panels` to `Super+Esc` and `hayashi-shell msg launcher` to `Super+Space`
- point your idle daemon's lock command at `hayashi-shell msg lock`

The installed shell runs from the Nix store, so it only changes when you update the flake. To work on it, run `hayashi-shell dev ~/path/to/hayashi/shell`: the shell restarts from your working copy and reloads as you edit. `hayashi-shell dev off` goes back to the store copy, and `hayashi-shell status` shows which one is running.

For lock screen work, `HAYASHI_SHELL_FAKE_LOCK=1 qs -p shell/` shows the lock screen in an ordinary window that accepts any password, so a bug can't lock you out.

Without Nix, run `qs -p` on this directory, install Quickshell 0.3 or newer, Material Symbols Rounded, Space Grotesk and SpaceMono Nerd Font, and create `/etc/pam.d/hayashi-shell` (a copy of your distro's `login` or `swaylock` file works).
