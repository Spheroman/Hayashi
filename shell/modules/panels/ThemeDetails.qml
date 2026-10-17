import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.widgets

// Theme card: dark or light, and the seed hue the whole palette is built
// from (presets, or any hue on the strip). The shell recolors as it changes;
// see Settings for what else follows.
ColumnLayout {
    id: root

    spacing: 6

    // Primary, the most colorful role, at a given hue in the current theme.
    function swatch(hue: real): color {
        const r = Theme.roles.primary;
        return Theme.dark ? Theme.oklch(r[0], r[1], hue) : Theme.oklch(r[2], r[3], hue);
    }

    // ---- Mode ----

    Label {
        Layout.leftMargin: 4
        text: "MODE"
        font.pixelSize: 12
        font.weight: Font.DemiBold
        font.letterSpacing: 0.8
        color: Theme.fgSurfaceVariant
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 2

        Repeater {
            id: modes
            model: [
                { dark: true, label: "Dark", icon: "dark_mode" },
                { dark: false, label: "Light", icon: "light_mode" },
            ]

            delegate: Rectangle {
                required property var modelData
                required property int index
                readonly property bool current: Settings.dark === modelData.dark

                Layout.fillWidth: true
                implicitHeight: 44
                // A connected button group: the ends are round, the joins small.
                topLeftRadius: index === 0 ? 22 : 8
                bottomLeftRadius: index === 0 ? 22 : 8
                topRightRadius: index === modes.count - 1 ? 22 : 8
                bottomRightRadius: index === modes.count - 1 ? 22 : 8
                color: current ? Theme.secondaryContainer : Theme.surfaceContainerHigh

                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: modelData.icon
                        size: 18
                        filled: current
                        color: current ? Theme.fgSecondaryContainer : Theme.fgSurface
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        color: current ? Theme.fgSecondaryContainer : Theme.fgSurface
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Settings.dark = modelData.dark
                }
            }
        }
    }

    // ---- Color ----

    Label {
        Layout.leftMargin: 4
        Layout.topMargin: 6
        text: "COLOR"
        font.pixelSize: 12
        font.weight: Font.DemiBold
        font.letterSpacing: 0.8
        color: Theme.fgSurfaceVariant
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 0

        Repeater {
            model: [160, 200, 250, 290, 330, 25, 60, 100]

            delegate: Item {
                required property real modelData
                readonly property bool current: Math.abs(Settings.seedHue - modelData) < 0.5

                Layout.fillWidth: true
                implicitHeight: 44

                Rectangle {
                    anchors.centerIn: parent
                    width: 36
                    height: 36
                    radius: 18
                    color: "transparent"
                    border.width: current ? 2 : 0
                    border.color: Theme.fgSurface

                    Rectangle {
                        anchors.centerIn: parent
                        width: 28
                        height: 28
                        radius: 14
                        color: root.swatch(modelData)
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Settings.seedHue = modelData
                }
            }
        }
    }

    // Any hue: the strip shows each hue as it would look.
    RowLayout {
        Layout.fillWidth: true
        Layout.bottomMargin: 4
        spacing: 14

        Item {
            id: strip

            Layout.fillWidth: true
            implicitHeight: 30

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0 / 12; color: root.swatch(0) }
                    GradientStop { position: 1 / 12; color: root.swatch(30) }
                    GradientStop { position: 2 / 12; color: root.swatch(60) }
                    GradientStop { position: 3 / 12; color: root.swatch(90) }
                    GradientStop { position: 4 / 12; color: root.swatch(120) }
                    GradientStop { position: 5 / 12; color: root.swatch(150) }
                    GradientStop { position: 6 / 12; color: root.swatch(180) }
                    GradientStop { position: 7 / 12; color: root.swatch(210) }
                    GradientStop { position: 8 / 12; color: root.swatch(240) }
                    GradientStop { position: 9 / 12; color: root.swatch(270) }
                    GradientStop { position: 10 / 12; color: root.swatch(300) }
                    GradientStop { position: 11 / 12; color: root.swatch(330) }
                    GradientStop { position: 12 / 12; color: root.swatch(360) }
                }
            }

            // The handle: the current seed, ringed so it reads on any hue.
            Rectangle {
                x: Settings.seedHue / 360 * (strip.width - width)
                anchors.verticalCenter: parent.verticalCenter
                width: 30
                height: 30
                radius: 15
                color: root.swatch(Settings.seedHue)
                border.width: 3
                border.color: Theme.fgSurface
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                function update(mx) { Settings.seedHue = Math.round(Math.max(0, Math.min(1, (mx - 15) / (strip.width - 30))) * 360); }
                onPressed: mouse => update(mouse.x)
                onPositionChanged: mouse => { if (pressed) update(mouse.x); }
                onWheel: wheel => Settings.seedHue = (Settings.seedHue + (wheel.angleDelta.y > 0 ? 5 : -5) + 360) % 360
            }
        }

        Label {
            Layout.preferredWidth: 40
            horizontalAlignment: Text.AlignRight
            text: Math.round(Settings.seedHue) + "°"
            font.pixelSize: 13
            font.features: { "tnum": 1 }
            color: Theme.fgSurfaceVariant
        }
    }
}
