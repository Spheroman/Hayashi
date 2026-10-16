import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.config
import qs.services

// Popups in the card's top-right corner. They sit one gap in from the card
// edge with the window radius, so their corners share a center with the
// card's corner, like windows do.
PanelWindow {
    id: win

    anchors {
        top: true
        right: true
    }
    margins {
        top: Tokens.border + Tokens.gaps
        right: Tokens.border + Tokens.gaps
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "card-notifications"
    color: "transparent"

    // Stays mapped even with nothing to show: unmapping lets the compositor
    // fade the popups out (Hyprland does), which ghosts over the panel view.
    readonly property bool showing: Notifications.popups.length > 0 && !ShellState.panelsOpen

    implicitWidth: 400
    implicitHeight: Math.max(1, column.implicitHeight)
    mask: Region { item: inputArea }

    Item {
        id: inputArea
        width: win.showing ? column.width : 0
        height: win.showing ? column.height : 0
    }

    Column {
        id: column

        width: parent.width
        spacing: 8
        visible: win.showing

        Repeater {
            model: Notifications.popups

            delegate: NotificationCard {
                required property var modelData
                entry: modelData
                popup: true
                width: column.width
                radius: Tokens.windowRadius
            }
        }
    }
}
