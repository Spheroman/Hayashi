// Card and Base: a Material 3 shell. Design notes live in the Card and Base
// prototype; tuned values are in config/Tokens.qml.
import Quickshell
import Quickshell.Io
import QtQuick
import qs.services
import qs.modules

ShellRoot {
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
