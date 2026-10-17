import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import QtQuick
import qs.config
import qs.services

// Quick settings: two rows of three tiles that never move. Tapping a tile
// toggles it; its arrow opens its card directly below the tile's row
// (pushing only what's below down), and the tile stays put, outlined. One
// card is open at a time.
Item {
    id: root

    // The id of the tile whose card is open, or "".
    property string expanded: ""

    readonly property var rows: [["wifi", "bluetooth", "sound"], ["power", "theme", "dnd"]]
    readonly property int gap: 10
    readonly property real cell: (width - 2 * gap) / 3

    implicitHeight: column.implicitHeight

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var sink: Pipewire.defaultAudioSink
    PwObjectTracker { objects: [root.sink] }

    // Keep Wi-Fi fresh while the panel view is open; refresh often while
    // its card is showing.
    Connections {
        target: ShellState
        function onPanelsOpenChanged(): void {
            if (ShellState.panelsOpen) Wifi.refresh();
            else root.expanded = "";
        }
    }
    Binding {
        target: Wifi
        property: "watching"
        value: root.expanded === "wifi" && ShellState.panelsOpen
    }

    readonly property int profile: PowerProfiles.profile
    readonly property string profileName: profile === PowerProfile.PowerSaver ? "Power saver"
        : profile === PowerProfile.Performance ? "Performance" : "Balanced"

    function info(id) {
        switch (id) {
        case "wifi": return {
            icon: Wifi.enabled ? "wifi" : "wifi_off", label: "Wi-Fi", on: Wifi.enabled,
            detail: !Wifi.enabled ? "Off" : Wifi.active ? Wifi.active.ssid : "Not connected",
            details: wifiDetails };
        case "bluetooth": {
            const connected = Bluetooth.devices.values.filter(d => d.connected);
            return {
                icon: "bluetooth", label: "Bluetooth", available: root.adapter !== null,
                on: root.adapter?.enabled ?? false,
                detail: !root.adapter ? "Unavailable" : !root.adapter.enabled ? "Off"
                    : connected.length > 0 ? connected.map(d => d.name).join(", ") : "On",
                details: bluetoothDetails };
        }
        case "sound": {
            const muted = root.sink?.audio?.muted ?? false;
            return {
                icon: muted ? "volume_off" : "volume_up", label: "Sound", on: !muted,
                available: root.sink !== null,
                detail: muted ? "Muted" : (root.sink?.description || root.sink?.nickname || "No output"),
                details: soundDetails };
        }
        case "power": return {
            icon: profile === PowerProfile.PowerSaver ? "eco" : profile === PowerProfile.Performance ? "bolt" : "speed",
            label: "Power", detail: profileName, on: profile !== PowerProfile.Balanced,
            details: powerDetails };
        case "theme": return {
            icon: Settings.dark ? "dark_mode" : "light_mode", label: "Theme", on: Settings.dark,
            detail: Settings.dark ? "Dark" : "Light", details: themeDetails };
        case "dnd": return { icon: "do_not_disturb_on", label: "Do not disturb", detail: Notifications.dnd ? "On" : "Off", on: Notifications.dnd };
        }
        return {};
    }

    function toggle(id): void {
        switch (id) {
        case "wifi": Wifi.setEnabled(!Wifi.enabled); break;
        case "bluetooth": if (root.adapter) root.adapter.enabled = !root.adapter.enabled; break;
        case "sound": if (root.sink?.audio) root.sink.audio.muted = !root.sink.audio.muted; break;
        case "power": {
            const order = [PowerProfile.PowerSaver, PowerProfile.Balanced];
            if (PowerProfiles.hasPerformanceProfile) order.push(PowerProfile.Performance);
            PowerProfiles.profile = order[(order.indexOf(profile) + 1) % order.length];
            break;
        }
        case "theme": Settings.dark = !Settings.dark; break;
        case "dnd": Notifications.dnd = !Notifications.dnd; break;
        }
    }

    Component { id: wifiDetails; WifiDetails {} }
    Component { id: bluetoothDetails; BluetoothDetails {} }
    Component { id: soundDetails; SoundDetails {} }
    Component { id: powerDetails; PowerDetails {} }
    Component { id: themeDetails; ThemeDetails {} }

    Column {
        id: column

        width: parent.width
        spacing: root.gap

        Repeater {
            model: root.rows

            delegate: Column {
                id: row

                required property var modelData
                readonly property bool cardHere: modelData.includes(root.expanded)

                width: column.width
                spacing: 0

                Row {
                    spacing: root.gap

                    Repeater {
                        model: row.modelData

                        delegate: Tile {
                            required property string modelData
                            readonly property var i: root.info(modelData)

                            width: root.cell
                            icon: i.icon ?? ""
                            label: i.label ?? ""
                            detail: i.detail ?? ""
                            on: i.on ?? false
                            available: i.available ?? true
                            hasDetails: (i.details ?? null) !== null
                            open: root.expanded === modelData

                            onClicked: root.toggle(modelData)
                            onExpandToggled: root.expanded = root.expanded === modelData ? "" : modelData
                        }
                    }
                }

                // The gap above the card grows with it, so nothing jumps.
                Item {
                    width: 1
                    height: Math.min(root.gap, card.height)
                }

                DetailCard {
                    id: card
                    width: column.width
                    content: row.cardHere ? (root.info(root.expanded).details ?? null) : null
                }
            }
        }
    }
}
