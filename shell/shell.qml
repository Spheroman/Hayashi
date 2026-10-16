// Hayashi's shell. See README.md for the design; tuned values are in
// config/Tokens.qml.
import Quickshell
import Quickshell.Io
import QtQuick
import qs.services
import qs.modules
import qs.modules.notifications

ShellRoot {
    // One set of notification popups, on the first screen.
    NotificationPopups { screen: Quickshell.screens[0] }

    Variants {
        model: Quickshell.screens

        Scope {
            id: perScreen

            required property ShellScreen modelData

            Background { screen: perScreen.modelData }
            Frame { screen: perScreen.modelData }
            PanelsOverlay { screen: perScreen.modelData }
        }
    }

    // `qs ipc call panels toggle`, bound to Super+Esc in Hyprland.
    IpcHandler {
        target: "panels"

        function toggle(): void { ShellState.togglePanels(); }
        function open(): void { ShellState.panelsOpen = true; }
        function close(): void { ShellState.panelsOpen = false; }
    }
}
