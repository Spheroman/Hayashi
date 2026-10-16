// The login screen. Runs under greetd inside a minimal compositor (cage); see
// nix/nixos-shell.nix. It's the shell's "no card" state: the base, a status
// column where the bar is, a clock and the sign-in card. After a successful
// login the session's shell slides the card in (HAYASHI_SHELL_INTRO).
//
// To try it in a running session: `fakegreet "qs -p shell/greeter.qml"`
// (fakegreet ships with greetd; user "user", password "password").
import Quickshell
import QtQuick
import qs.config
import qs.modules.greeter

ShellRoot {
    FloatingWindow {
        // cage fullscreens it; the size only matters when testing in a session.
        implicitWidth: 1920
        implicitHeight: 1200
        color: Theme.surface

        GreeterScreen {
            anchors.fill: parent
        }
    }
}
