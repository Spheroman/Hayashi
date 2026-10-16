import Quickshell.Bluetooth
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.widgets

// Bluetooth card: connected and paired devices (tap to connect or
// disconnect, the cross to forget), and while scanning, nearby devices to
// pair.
ColumnLayout {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool on: adapter?.enabled ?? false
    readonly property var devices: (adapter?.devices.values ?? [])
        .filter(d => d.paired || d.connected || adapter.discovering)
        .sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || a.name.localeCompare(b.name))

    spacing: 2

    function iconFor(icon) {
        if (/headset|headphone/.test(icon)) return "headphones";
        if (/audio|speaker/.test(icon)) return "speaker";
        if (/mouse/.test(icon)) return "mouse";
        if (/keyboard/.test(icon)) return "keyboard";
        if (/phone/.test(icon)) return "smartphone";
        if (/gaming|joystick/.test(icon)) return "sports_esports";
        if (/computer/.test(icon)) return "computer";
        return "bluetooth";
    }

    Label {
        Layout.fillWidth: true
        Layout.leftMargin: 12
        Layout.bottomMargin: 6
        visible: !root.on || root.devices.length === 0
        text: !root.adapter ? "No Bluetooth adapter." : !root.on ? "Bluetooth is off."
            : root.adapter.discovering ? "Looking for devices…" : "No paired devices."
        font.pixelSize: 13
        color: Theme.fgSurfaceVariant
    }

    Flickable {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(list.implicitHeight, 300)
        visible: root.on && root.devices.length > 0
        contentHeight: list.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: list

            width: parent.width
            spacing: 2

            Repeater {
                model: root.devices

                delegate: DetailRow {
                    required property var modelData
                    readonly property var d: modelData

                    Layout.fillWidth: true
                    icon: root.iconFor(d.icon)
                    iconFilled: d.connected
                    selected: d.connected
                    title: d.name || d.address
                    subtitle: d.pairing ? "Pairing…"
                        : d.state === BluetoothDeviceState.Connecting ? "Connecting…"
                        : d.state === BluetoothDeviceState.Disconnecting ? "Disconnecting…"
                        : d.connected ? "Connected" + (d.batteryAvailable ? " · " + Math.round(d.battery * 100) + "%" : "")
                        : d.paired ? "Paired" : "Tap to pair"
                    trailingIcon: d.paired ? "close" : ""

                    onClicked: {
                        if (!d.paired) d.pair();
                        else if (d.connected) d.disconnect();
                        else d.connect();
                    }
                    onTrailingClicked: d.forget()
                }
            }
        }
    }

    RowLayout {
        Layout.topMargin: 6
        Layout.bottomMargin: 8
        visible: root.on

        PillButton {
            icon: root.adapter?.discovering ? "stop" : "bluetooth_searching"
            text: root.adapter?.discovering ? "Stop scanning" : "Pair new device"
            onClicked: root.adapter.discovering = !root.adapter.discovering
        }
    }
}
