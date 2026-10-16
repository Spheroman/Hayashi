import QtQuick
import qs.config
import qs.widgets

// A small Material button: filled (primary), tonal, or outlined.
Rectangle {
    id: root

    property string text
    property string icon: ""
    property string kind: "tonal"  // "filled", "tonal" or "outlined"
    property bool active: true
    signal clicked

    implicitWidth: row.implicitWidth + 28
    implicitHeight: 36
    radius: height / 2
    opacity: active ? 1 : 0.45
    color: kind === "filled" ? Theme.primary : kind === "tonal" ? Theme.secondaryContainer
        : hover.hovered ? Theme.surfaceContainerHigh : "transparent"
    border.width: kind === "outlined" ? 1.5 : 0
    border.color: Theme.outlineVariant

    readonly property color fg: kind === "filled" ? Theme.fgPrimary : kind === "tonal" ? Theme.fgSecondaryContainer : Theme.fgSurface

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 6

        Icon {
            visible: root.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            name: root.icon
            size: 18
            color: root.fg
        }
        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            font.pixelSize: 13
            font.weight: Font.DemiBold
            color: root.fg
        }
    }

    HoverHandler { id: hover }
    TapHandler {
        enabled: root.active
        onTapped: root.clicked()
    }
}
