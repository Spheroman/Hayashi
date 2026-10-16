import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services

GridLayout {
    id: root

    columns: 3
    columnSpacing: 10
    rowSpacing: 10

    // Wi-Fi state comes from nmcli, refreshed whenever the panels open.
    property bool wifiOn: false
    property string ssid: ""

    Process {
        id: wifiProc
        command: ["sh", "-c", "nmcli -t -f WIFI general; nmcli -t -f active,ssid device wifi | sed -n 's/^yes://p' | head -n1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                root.wifiOn = lines[0] === "enabled";
                root.ssid = lines[1] ?? "";
            }
        }
    }
    Connections {
        target: ShellState
        function onPanelsOpenChanged(): void {
            if (ShellState.panelsOpen) wifiProc.running = true;
        }
    }
    Component.onCompleted: wifiProc.running = true

    Tile {
        Layout.fillWidth: true
        icon: root.wifiOn ? "wifi" : "wifi_off"
        label: "Wi-Fi"
        detail: !root.wifiOn ? "Off" : root.ssid !== "" ? root.ssid : "Not connected"
        on: root.wifiOn
        onClicked: {
            root.wifiOn = !root.wifiOn;
            Quickshell.execDetached(["nmcli", "radio", "wifi", root.wifiOn ? "on" : "off"]);
        }
    }

    Tile {
        Layout.fillWidth: true
        readonly property var adapter: Bluetooth.defaultAdapter
        readonly property var connected: Bluetooth.devices.values.filter(d => d.connected)
        icon: "bluetooth"
        label: "Bluetooth"
        available: adapter !== null
        on: adapter?.enabled ?? false
        detail: !available ? "Unavailable" : !on ? "Off" : connected.length > 0 ? connected[0].name : "On"
        onClicked: adapter.enabled = !adapter.enabled
    }

    Tile {
        Layout.fillWidth: true
        readonly property int profile: PowerProfiles.profile
        icon: profile === PowerProfile.PowerSaver ? "eco" : profile === PowerProfile.Performance ? "bolt" : "speed"
        label: "Power"
        detail: profile === PowerProfile.PowerSaver ? "Power saver" : profile === PowerProfile.Performance ? "Performance" : "Balanced"
        on: profile !== PowerProfile.Balanced
        onClicked: {
            const order = [PowerProfile.PowerSaver, PowerProfile.Balanced];
            if (PowerProfiles.hasPerformanceProfile) order.push(PowerProfile.Performance);
            PowerProfiles.profile = order[(order.indexOf(profile) + 1) % order.length];
        }
    }

    Tile {
        Layout.fillWidth: true
        icon: "dark_mode"
        label: "Dark theme"
        detail: Theme.dark ? "On" : "Off"
        on: Theme.dark
        onClicked: Theme.dark = !Theme.dark
    }
}
