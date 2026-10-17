import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.widgets

// Wi-Fi card: nearby networks, connected first. Tapping a saved or open
// network connects; a new secured one opens a password field. The
// connected network offers Disconnect and Forget.
ColumnLayout {
    id: root

    property string openSsid: ""

    spacing: 4

    // The rows come from a ListModel that's updated in place, matched by
    // network name, rather than straight from Wifi.networks (a new array on
    // every refresh). That keeps each row, and a half-typed password,
    // across refreshes.
    ListModel { id: netModel }

    function sync(): void {
        const target = Wifi.networks;
        for (let i = 0; i < target.length; i++) {
            const t = target[i];
            const row = { ssid: t.ssid, strength: t.signal, secure: t.secure, active: t.active, saved: t.saved };
            let j = -1;
            for (let k = i; k < netModel.count; k++) {
                if (netModel.get(k).ssid === t.ssid) { j = k; break; }
            }
            if (j === -1) {
                netModel.insert(i, row);
            } else {
                if (j !== i) netModel.move(j, i, 1);
                netModel.set(i, row);
            }
        }
        if (netModel.count > target.length) netModel.remove(target.length, netModel.count - target.length);
    }

    Connections {
        target: Wifi
        function onNetworksChanged(): void { root.sync(); }
    }
    Component.onCompleted: sync()

    // No automatic refresh while a password field is open.
    Binding {
        target: Wifi
        property: "paused"
        value: root.openSsid !== ""
    }

    function strength(signal) {
        return signal >= 75 ? "signal_wifi_4_bar" : signal >= 50 ? "network_wifi_3_bar"
            : signal >= 25 ? "network_wifi_2_bar" : "network_wifi_1_bar";
    }

    Label {
        Layout.fillWidth: true
        Layout.leftMargin: 12
        visible: Wifi.error !== ""
        text: Wifi.error
        wrapMode: Text.Wrap
        font.pixelSize: 13
        color: Theme.error
    }

    Label {
        Layout.fillWidth: true
        Layout.leftMargin: 12
        Layout.bottomMargin: 8
        visible: !Wifi.enabled || Wifi.networks.length === 0
        text: !Wifi.enabled ? "Wi-Fi is off." : "Looking for networks…"
        font.pixelSize: 13
        color: Theme.fgSurfaceVariant
    }

    Flickable {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(list.implicitHeight, 330)
        visible: Wifi.enabled && Wifi.networks.length > 0
        contentHeight: list.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: list

            width: parent.width
            spacing: 2

            Repeater {
                model: netModel

                delegate: DetailRow {
                    id: row

                    required property string ssid
                    required property int strength
                    required property bool secure
                    required property bool active
                    required property bool saved
                    readonly property bool isOpen: root.openSsid === ssid

                    Layout.fillWidth: true
                    icon: root.strength(strength)
                    iconFilled: active
                    selected: active
                    open: isOpen
                    title: ssid
                    subtitle: Wifi.connecting === ssid ? "Connecting…"
                        : active ? "Connected" : saved ? "Saved" : secure ? "Secured" : "Open"
                    trailingIcon: secure ? "lock" : ""

                    onClicked: {
                        if (isOpen) {
                            root.openSsid = "";
                        } else if (!active && (saved || !secure)) {
                            Wifi.connect(ssid, "");
                        } else {
                            root.openSsid = ssid;
                            Qt.callLater(() => password.forceActiveFocus());
                        }
                    }
                    onTrailingClicked: clicked()

                    // Connected or saved: actions.
                    RowLayout {
                        visible: active || saved
                        spacing: 8

                        PillButton {
                            visible: active
                            text: "Disconnect"
                            onClicked: { Wifi.disconnect(ssid); root.openSsid = ""; }
                        }
                        PillButton {
                            visible: !active
                            text: "Connect"
                            kind: "filled"
                            onClicked: { Wifi.connect(ssid, ""); root.openSsid = ""; }
                        }
                        PillButton {
                            text: "Forget"
                            kind: "outlined"
                            onClicked: { Wifi.forget(ssid); root.openSsid = ""; }
                        }
                    }

                    // New secured network: password.
                    RowLayout {
                        visible: !active && !saved && secure
                        spacing: 8

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 40
                            radius: 20
                            color: Theme.surfaceContainerHighest
                            border.width: 2
                            border.color: password.activeFocus ? Theme.primary : "transparent"

                            TextInput {
                                id: password

                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16
                                verticalAlignment: TextInput.AlignVCenter
                                echoMode: TextInput.Password
                                passwordCharacter: "•"
                                color: Theme.fgSurface
                                font.family: Tokens.fontFamily
                                font.pixelSize: 14
                                clip: true
                                onAccepted: connectButton.clicked()

                                Label {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: password.text === ""
                                    text: "Password"
                                    font.pixelSize: 14
                                    color: Theme.fgSurfaceVariant
                                }
                            }
                        }
                        PillButton {
                            id: connectButton
                            text: "Connect"
                            kind: "filled"
                            active: password.text.length >= 8
                            onClicked: {
                                if (password.text.length < 8) return;
                                Wifi.connect(ssid, password.text);
                                password.text = "";
                                root.openSsid = "";
                            }
                        }
                    }
                }
            }
        }
    }

    Item { implicitHeight: 4 }
}
