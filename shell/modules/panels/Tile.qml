import QtQuick
import QtQuick.Layouts
import qs.config
import qs.widgets

// A quick-settings toggle. "On" tiles fill with the primary container and
// tighten their corners.
Rectangle {
    id: root

    property string icon
    property string label
    property string detail
    property bool on: false
    property bool available: true
    signal clicked

    implicitHeight: 64
    radius: on ? 16 : 24
    color: on ? Theme.primaryContainer : Theme.surfaceContainerHigh
    opacity: available ? 1 : 0.5

    Behavior on radius {
        NumberAnimation { duration: 200; easing.type: Easing.BezierSpline; easing.bezierCurve: Tokens.returnCurve }
    }
    Behavior on color {
        ColorAnimation { duration: 150 }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 14
        spacing: 12

        Icon {
            name: root.icon
            filled: root.on
            color: root.on ? Theme.fgPrimaryContainer : Theme.fgSurface
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Label {
                Layout.fillWidth: true
                text: root.label
                font.weight: Font.DemiBold
                color: root.on ? Theme.fgPrimaryContainer : Theme.fgSurface
            }
            Label {
                Layout.fillWidth: true
                text: root.detail
                visible: text !== ""
                font.pixelSize: 12
                color: root.on ? Theme.fgPrimaryContainer : Theme.fgSurfaceVariant
            }
        }
    }

    TapHandler {
        enabled: root.available
        onTapped: root.clicked()
    }
}
