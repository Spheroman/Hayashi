import QtQuick
import QtQuick.Layouts
import qs.config
import qs.widgets

// A quick-settings tile. Tapping it toggles; "on" tiles fill with the
// primary container and tighten their corners. Tiles with details have an
// arrow that opens them as a card below the tile's row (see Tiles.qml); the
// tile itself stays in place, outlined while its card is open.
Rectangle {
    id: root

    property string icon
    property string label
    property string detail
    property bool on: false
    property bool available: true
    property bool hasDetails: false
    property bool open: false

    signal clicked
    signal expandToggled

    implicitHeight: 64
    radius: on ? 16 : 24
    color: on ? Theme.primaryContainer : Theme.surfaceContainerHigh
    border.width: open ? 2 : 0
    border.color: Theme.primary
    opacity: available ? 1 : 0.5

    Behavior on radius {
        NumberAnimation { duration: 200; easing.type: Easing.BezierSpline; easing.bezierCurve: Tokens.returnCurve }
    }
    Behavior on color {
        ColorAnimation { duration: 150 }
    }

    readonly property color fg: on ? Theme.fgPrimaryContainer : Theme.fgSurface
    readonly property color fgDim: on ? Theme.fgPrimaryContainer : Theme.fgSurfaceVariant

    // Clicks are MouseAreas rather than TapHandlers: a MouseArea accepts the
    // click, so the arrow (on top) doesn't also fire this tile-wide one
    // underneath. TapHandlers don't exclude each other.
    MouseArea {
        anchors.fill: parent
        enabled: root.available
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: root.hasDetails ? 6 : 14
        spacing: 12

        Icon {
            name: root.icon
            filled: root.on
            color: root.fg
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Label {
                Layout.fillWidth: true
                text: root.label
                font.weight: Font.DemiBold
                color: root.fg
            }
            Label {
                Layout.fillWidth: true
                text: root.detail
                visible: text !== ""
                font.pixelSize: 12
                color: root.fgDim
            }
        }

        Rectangle {
            visible: root.hasDetails
            implicitWidth: 40
            implicitHeight: 40
            radius: 20
            color: arrowArea.containsMouse ? (root.on ? Theme.primary : Theme.surfaceContainerHighest) : "transparent"

            Icon {
                anchors.centerIn: parent
                name: "expand_more"
                rotation: root.open ? 180 : 0
                color: root.on && arrowArea.containsMouse ? Theme.fgPrimary : root.fg
                Behavior on rotation {
                    NumberAnimation { duration: 220; easing.type: Easing.BezierSpline; easing.bezierCurve: Tokens.returnCurve }
                }
            }
            MouseArea {
                id: arrowArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.expandToggled()
            }
        }
    }
}
