import Quickshell
import QtQuick
import qs.config
import qs.services
import qs.widgets

// Lock, log out, suspend, restart, shut down. Restart and shut down ask for a
// second tap within three seconds.
Flow {
    id: root

    spacing: 10

    property string armed: ""
    Timer {
        id: disarm
        interval: 3000
        onTriggered: root.armed = ""
    }

    function run(id: string, command: var, confirm: bool): void {
        if (confirm && armed !== id) {
            armed = id;
            disarm.restart();
            return;
        }
        armed = "";
        ShellState.panelsOpen = false;
        if (command === "exit") Compositor.exitSession();
        else Quickshell.execDetached(command);
    }

    SessionButton { icon: "lock"; label: "Lock"; onClicked: root.run("lock", ["loginctl", "lock-session"], false) }
    SessionButton { icon: "logout"; label: "Log out"; onClicked: root.run("logout", "exit", false) }
    SessionButton { icon: "bedtime"; label: "Suspend"; onClicked: root.run("suspend", ["systemctl", "suspend"], false) }
    SessionButton {
        icon: "restart_alt"
        label: root.armed === "restart" ? "Tap again to restart" : "Restart"
        onClicked: root.run("restart", ["systemctl", "reboot"], true)
    }
    SessionButton {
        icon: "power_settings_new"
        label: root.armed === "poweroff" ? "Tap again to shut down" : "Shut down"
        danger: true
        onClicked: root.run("poweroff", ["systemctl", "poweroff"], true)
    }

    component SessionButton: Rectangle {
        id: btn

        property string icon
        property string label
        property bool danger: false
        signal clicked

        width: row.implicitWidth + 32
        height: 42
        radius: height / 2
        color: danger ? Theme.tertiaryContainer : hover.hovered ? Theme.surfaceContainerHigh : "transparent"
        border.width: danger ? 0 : 1.5
        border.color: Theme.outlineVariant

        Row {
            id: row

            anchors.centerIn: parent
            spacing: 8

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: btn.icon
                size: 20
                color: btn.danger ? Theme.fgTertiaryContainer : Theme.fgSurface
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: btn.label
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: btn.danger ? Theme.fgTertiaryContainer : Theme.fgSurface
            }
        }

        HoverHandler { id: hover }
        TapHandler { onTapped: btn.clicked() }
    }
}
