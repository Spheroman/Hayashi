import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.widgets

// The first MPRIS player, if any.
Rectangle {
    id: root

    readonly property var player: Mpris.players.values.length > 0 ? Mpris.players.values[0] : null

    visible: player !== null
    implicitHeight: 116
    radius: 28
    color: Theme.secondaryContainer

    RowLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        Rectangle {
            Layout.preferredWidth: 84
            Layout.preferredHeight: 84
            radius: 18
            color: Theme.primaryContainer
            clip: true

            Image {
                anchors.fill: parent
                source: root.player?.trackArtUrl ?? ""
                fillMode: Image.PreserveAspectCrop
                visible: status === Image.Ready
            }
            Icon {
                anchors.centerIn: parent
                name: "music_note"
                size: 32
                color: Theme.fgPrimaryContainer
                visible: !root.player?.trackArtUrl
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Label {
                Layout.fillWidth: true
                text: root.player?.trackTitle || root.player?.identity || ""
                font.pixelSize: 16
                font.weight: Font.DemiBold
                color: Theme.fgSecondaryContainer
            }
            Label {
                Layout.fillWidth: true
                text: root.player?.trackArtist ?? ""
                font.pixelSize: 13
                color: Theme.fgSecondaryContainer
                opacity: 0.8
            }
        }

        Row {
            spacing: 4

            MediaButton { icon: "skip_previous"; enabled: root.player?.canGoPrevious ?? false; onClicked: root.player.previous() }
            MediaButton {
                icon: root.player?.isPlaying ? "pause" : "play_arrow"
                primary: true
                enabled: root.player?.canTogglePlaying ?? false
                onClicked: root.player.togglePlaying()
            }
            MediaButton { icon: "skip_next"; enabled: root.player?.canGoNext ?? false; onClicked: root.player.next() }
        }
    }

    component MediaButton: Rectangle {
        id: btn

        property string icon
        property bool primary: false
        signal clicked

        width: 40
        height: 40
        radius: primary ? 14 : 20
        color: primary ? Theme.fgSecondaryContainer : "transparent"
        opacity: enabled ? 1 : 0.4

        Icon {
            anchors.centerIn: parent
            name: btn.icon
            filled: btn.primary
            color: btn.primary ? Theme.secondaryContainer : Theme.fgSecondaryContainer
        }
        TapHandler {
            enabled: btn.enabled
            onTapped: btn.clicked()
        }
    }
}
