import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.widgets

// Sound card: pick the output and input devices (the chosen one gets a
// volume slider), and set each playing app's volume.
ColumnLayout {
    id: root

    readonly property var nodes: Pipewire.nodes.values.filter(n => n.audio)
    readonly property var outputs: nodes.filter(n => n.isSink && !n.isStream)
    readonly property var inputs: nodes.filter(n => !n.isSink && !n.isStream)
    readonly property var apps: nodes.filter(n => n.isStream && n.properties["media.class"] === "Stream/Output/Audio")

    PwObjectTracker { objects: root.nodes }

    spacing: 2

    function name(n) { return n.description || n.nickname || n.name; }

    component Section: Label {
        Layout.fillWidth: true
        Layout.leftMargin: 12
        Layout.topMargin: 8
        Layout.bottomMargin: 2
        font.pixelSize: 12
        font.weight: Font.DemiBold
        font.letterSpacing: 0.8
        color: Theme.fgSurfaceVariant
    }

    component DeviceList: ColumnLayout {
        id: devices

        property var model: []
        property var current: null
        property string icon
        signal picked(var node)

        Layout.fillWidth: true
        spacing: 2

        Repeater {
            model: devices.model

            delegate: ColumnLayout {
                required property var modelData
                readonly property bool isCurrent: modelData === devices.current

                Layout.fillWidth: true
                spacing: 2

                DetailRow {
                    Layout.fillWidth: true
                    icon: isCurrent ? devices.icon : "radio_button_unchecked"
                    iconFilled: isCurrent
                    selected: isCurrent
                    title: root.name(modelData)
                    subtitle: modelData.audio.muted ? "Muted" : ""
                    onClicked: devices.picked(modelData)
                }
                LevelSlider {
                    Layout.fillWidth: true
                    Layout.leftMargin: 12
                    Layout.rightMargin: 12
                    Layout.bottomMargin: 6
                    visible: isCurrent
                    icon: modelData.audio.muted ? "volume_off" : "volume_up"
                    value: modelData.audio.volume
                    onMoved: v => { modelData.audio.muted = false; modelData.audio.volume = v; }
                }
            }
        }
    }

    Section { text: "OUTPUT" }
    DeviceList {
        model: root.outputs
        current: Pipewire.defaultAudioSink
        icon: "speaker"
        onPicked: node => Pipewire.preferredDefaultAudioSink = node
    }

    Section { text: "INPUT"; visible: root.inputs.length > 0 }
    DeviceList {
        model: root.inputs
        current: Pipewire.defaultAudioSource
        icon: "mic"
        onPicked: node => Pipewire.preferredDefaultAudioSource = node
    }

    Section { text: "APPS"; visible: root.apps.length > 0 }
    Repeater {
        model: root.apps

        delegate: ColumnLayout {
            required property var modelData

            Layout.fillWidth: true
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            spacing: 2

            Label {
                text: modelData.properties["application.name"] || root.name(modelData)
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }
            LevelSlider {
                Layout.fillWidth: true
                icon: modelData.audio.muted ? "volume_off" : "music_note"
                value: modelData.audio.volume
                onMoved: v => { modelData.audio.muted = false; modelData.audio.volume = v; }
            }
        }
    }

    Item { implicitHeight: 8 }
}
