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
                model: Wifi.networks

                delegate: DetailRow {
                    id: row

                    required property var modelData
                    readonly property var n: modelData
                    readonly property bool isOpen: root.openSsid === n.ssid

                    Layout.fillWidth: true
                    icon: root.strength(n.signal)
                    iconFilled: n.active
                    selected: n.active
                    open: isOpen
                    title: n.ssid
                    subtitle: Wifi.connecting === n.ssid ? "Connecting…"
                        : n.active ? "Connected" : n.saved ? "Saved" : n.secure ? "Secured" : "Open"
                    trailingIcon: n.secure ? "lock" : ""

                    onClicked: {
                        if (isOpen) {
                            root.openSsid = "";
                        } else if (!n.active && (n.saved || !n.secure)) {
                            Wifi.connect(n.ssid, "");
                        } else {
                            root.openSsid = n.ssid;
                            Qt.callLater(() => password.forceActiveFocus());
                        }
                    }
                    onTrailingClicked: clicked()

                    // Connected or saved: actions.
                    RowLayout {
                        visible: n.active || n.saved
                        spacing: 8

                        PillButton {
                            visible: n.active
                            text: "Disconnect"
                            onClicked: { Wifi.disconnect(n.ssid); root.openSsid = ""; }
                        }
                        PillButton {
                            visible: !n.active
                            text: "Connect"
                            kind: "filled"
                            onClicked: { Wifi.connect(n.ssid, ""); root.openSsid = ""; }
                        }
                        PillButton {
                            text: "Forget"
                            kind: "outlined"
                            onClicked: { Wifi.forget(n.ssid); root.openSsid = ""; }
                        }
                    }

                    // New secured network: password.
                    RowLayout {
                        visible: !n.active && !n.saved && n.secure
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
                                Wifi.connect(n.ssid, password.text);
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
