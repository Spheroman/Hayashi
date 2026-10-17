import QtQuick
import QtQuick.Layouts
import qs.config
import qs.widgets

// A row in an expanded tile's list: icon, title and subtitle, an optional
// trailing icon, and an area below it that opens when `open` is set.
Rectangle {
    id: root

    property string icon
    property bool iconFilled: false
    property string title
    property string subtitle
    property string trailingIcon: ""
    property bool selected: false
    property bool open: false
    default property alias extra: extraColumn.data

    signal clicked
    signal trailingClicked

    implicitHeight: header.height + (open ? extraColumn.implicitHeight + 10 : 0)
    radius: 18
    color: selected ? Theme.secondaryContainer : hover.hovered || open ? Theme.surfaceContainerHigh : "transparent"

    readonly property color fg: selected ? Theme.fgSecondaryContainer : Theme.fgSurface
    readonly property color fgDim: selected ? Theme.fgSecondaryContainer : Theme.fgSurfaceVariant

    HoverHandler { id: hover }

    Item {
        id: header

        width: parent.width
        height: 54

        // MouseAreas (not TapHandlers), so the trailing button's click
        // doesn't also fire the row's.
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.clicked()
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 8
            spacing: 12

            Icon {
                name: root.icon
                filled: root.iconFilled
                color: root.fg
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Label {
                    Layout.fillWidth: true
                    text: root.title
                    font.weight: Font.DemiBold
                    color: root.fg
                }
                Label {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.subtitle
                    font.pixelSize: 12
                    color: root.fgDim
                }
            }
            Rectangle {
                visible: root.trailingIcon !== ""
                implicitWidth: 36
                implicitHeight: 36
                radius: 18
                color: trailingArea.containsMouse ? Theme.surfaceContainerHighest : "transparent"

                Icon {
                    anchors.centerIn: parent
                    name: root.trailingIcon
                    size: 20
                    color: root.fgDim
                }
                MouseArea {
                    id: trailingArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.trailingClicked()
                }
            }
        }
    }

    ColumnLayout {
        id: extraColumn

        y: header.height
        x: 12
        width: parent.width - 24
        visible: root.open
        spacing: 8
    }
}
