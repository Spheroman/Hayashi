import QtQuick
import QtQuick.Layouts
import qs.config
import qs.widgets

// A quick-settings tile. Tapping it toggles; "on" tiles fill with the
// primary container and tighten their corners. Tiles with details have an
// arrow that expands them in place into a full-width card: the header keeps
// a switch, and the `details` component fills the body.
Rectangle {
    id: root

    property string icon
    property string label
    property string detail
    property bool on: false
    property bool available: true
    property bool toggleable: true
    property Component details: null
    property bool expanded: false

    signal clicked
    signal expandToggled

    implicitHeight: expanded ? header.height + body.height + 16 : 64
    radius: expanded ? 28 : on ? 16 : 24
    color: expanded ? Theme.surfaceContainer : on ? Theme.primaryContainer : Theme.surfaceContainerHigh
    opacity: available ? 1 : 0.5
    clip: true

    Behavior on radius {
        NumberAnimation { duration: 200; easing.type: Easing.BezierSpline; easing.bezierCurve: Tokens.returnCurve }
    }
    Behavior on color {
        ColorAnimation { duration: 150 }
    }

    readonly property color fg: !expanded && on ? Theme.fgPrimaryContainer : Theme.fgSurface
    readonly property color fgDim: !expanded && on ? Theme.fgPrimaryContainer : Theme.fgSurfaceVariant

    Item {
        id: header

        width: parent.width
        height: 64

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: root.details ? 6 : 14
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

            // Expanded: a switch takes over the tile's on/off fill.
            Rectangle {
                visible: root.expanded && root.toggleable
                implicitWidth: 52
                implicitHeight: 32
                radius: 16
                color: root.on ? Theme.primary : Theme.surfaceContainerHighest
                border.width: root.on ? 0 : 2
                border.color: Theme.outline

                Rectangle {
                    width: root.on ? 24 : 16
                    height: width
                    radius: width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    x: root.on ? parent.width - width - 4 : 8
                    color: root.on ? Theme.fgPrimary : Theme.outline
                    Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.BezierSpline; easing.bezierCurve: Tokens.returnCurve } }
                }
                TapHandler {
                    enabled: root.available
                    onTapped: root.clicked()
                }
            }

            // The arrow that expands or collapses the card.
            Rectangle {
                visible: root.details !== null
                implicitWidth: 40
                implicitHeight: 40
                radius: 20
                color: arrowHover.hovered ? (root.on && !root.expanded ? Theme.primary : Theme.surfaceContainerHighest) : "transparent"

                Icon {
                    anchors.centerIn: parent
                    name: root.expanded ? "expand_less" : "chevron_right"
                    color: root.on && !root.expanded && arrowHover.hovered ? Theme.fgPrimary : root.fg
                }
                HoverHandler { id: arrowHover }
                TapHandler { onTapped: root.expandToggled() }
            }
        }

        TapHandler {
            enabled: root.available && (!root.expanded || !root.toggleable)
            onTapped: root.expanded ? root.expandToggled() : root.clicked()
        }
    }

    Loader {
        id: body

        y: header.height
        x: 16
        width: parent.width - 32
        active: root.expanded && root.details !== null
        visible: active
        sourceComponent: root.details
        height: active && item ? item.implicitHeight : 0
    }
}
