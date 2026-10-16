import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services

Rectangle {
    id: root

    implicitHeight: col.implicitHeight + 32
    radius: 26
    color: Theme.surfaceContainer

    readonly property var sink: Pipewire.defaultAudioSink
    PwObjectTracker { objects: [root.sink] }

    // Brightness goes through brightnessctl, read whenever the panels open.
    property real brightness: 0
    property bool hasBacklight: false
    Process {
        id: readBrightness
        command: ["brightnessctl", "-m"]
        stdout: StdioCollector {
            onStreamFinished: {
                // e.g. "amdgpu_bl1,backlight,123,48%,255"
                const f = text.trim().split(",");
                root.hasBacklight = f[1] === "backlight";
                if (root.hasBacklight) root.brightness = parseInt(f[3]) / 100;
            }
        }
    }
    Connections {
        target: ShellState
        function onPanelsOpenChanged(): void {
            if (ShellState.panelsOpen) readBrightness.running = true;
        }
    }
    Component.onCompleted: readBrightness.running = true

    ColumnLayout {
        id: col

        anchors.fill: parent
        anchors.margins: 16
        anchors.leftMargin: 18
        anchors.rightMargin: 18
        spacing: 12

        LevelSlider {
            Layout.fillWidth: true
            icon: root.sink?.audio?.muted ? "volume_off" : "volume_up"
            available: root.sink?.audio !== undefined && root.sink?.audio !== null
            value: root.sink?.audio?.volume ?? 0
            onMoved: v => { root.sink.audio.muted = false; root.sink.audio.volume = v; }
        }

        LevelSlider {
            Layout.fillWidth: true
            visible: root.hasBacklight
            icon: "brightness_6"
            value: root.brightness
            onMoved: v => {
                root.brightness = Math.max(0.01, v);
                Quickshell.execDetached(["brightnessctl", "-q", "set", Math.round(root.brightness * 100) + "%"]);
            }
        }
    }
}
