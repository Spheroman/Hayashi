import Quickshell
import Quickshell.Services.UPower
import QtQuick
import qs.config
import qs.services
import qs.widgets

// Left bar: workspaces at the top, status at the bottom.
Item {
    id: root

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 14
        spacing: 6

        Repeater {
            model: Compositor.visibleWorkspaces

            delegate: Rectangle {
                id: ws

                required property var modelData
                readonly property bool active: modelData.name === Compositor.activeName

                width: 34
                height: active ? 56 : 34
                radius: width / 2
                color: active ? Theme.primaryContainer : hover.hovered ? Theme.surfaceContainerHigh : "transparent"

                Behavior on height {
                    NumberAnimation { duration: 200; easing.type: Easing.BezierSpline; easing.bezierCurve: Tokens.returnCurve }
                }
                Behavior on color {
                    ColorAnimation { duration: 150 }
                }

                Label {
                    anchors.centerIn: parent
                    text: ws.modelData.name
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    font.italic: ws.modelData.windows === 0
                    color: ws.active ? Theme.fgPrimaryContainer : ws.modelData.windows > 0 ? Theme.fgSurfaceVariant : Theme.outline
                }

                HoverHandler { id: hover }
                TapHandler { onTapped: Compositor.focusWorkspace(ws.modelData.name) }
            }
        }
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 14
        spacing: 10

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: UPower.displayDevice.isLaptopBattery
            spacing: 2

            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                readonly property var dev: UPower.displayDevice
                name: dev.state === UPowerDeviceState.Charging || dev.state === UPowerDeviceState.FullyCharged ? "battery_charging_full" : "battery_full"
                color: Theme.fgSurfaceVariant
                size: 20
            }
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                // UPower reports 0-1 on some versions and 0-100 on others.
                readonly property real p: UPower.displayDevice.percentage
                text: Math.round(p > 1 ? p : p * 100) + "%"
                color: Theme.fgSurfaceVariant
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }
        }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, "HH") + "\n" + Qt.formatDateTime(clock.date, "mm")
            horizontalAlignment: Text.AlignHCenter
            lineHeight: 0.95
            font.pixelSize: 15
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
}
