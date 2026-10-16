import QtQuick
import QtQuick.Layouts
import qs.config
import qs.widgets

// A thick Material-style slider: a pill track filled with primary up to the value.
RowLayout {
    id: root

    property string icon
    property real value: 0  // 0-1
    property bool available: true
    signal moved(real value)

    spacing: 14
    opacity: available ? 1 : 0.5

    Icon {
        name: root.icon
        color: Theme.fgSurfaceVariant
    }

    Item {
        id: track

        Layout.fillWidth: true
        implicitHeight: 30

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Theme.surfaceContainerHighest
        }
        Rectangle {
            width: Math.max(height, track.width * Math.min(1, root.value))
            height: parent.height
            radius: height / 2
            color: Theme.primary
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.available
            function update(mx) { root.moved(Math.max(0, Math.min(1, mx / track.width))); }
            onPressed: mouse => update(mouse.x)
            onPositionChanged: mouse => { if (pressed) update(mouse.x); }
            onWheel: wheel => root.moved(Math.max(0, Math.min(1, root.value + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))))
        }
    }

    Label {
        Layout.preferredWidth: 40
        horizontalAlignment: Text.AlignRight
        text: Math.round(root.value * 100) + "%"
        font.pixelSize: 13
        font.features: { "tnum": 1 }
        color: Theme.fgSurfaceVariant
    }
}
