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
            const row = { ssid: t.ssid, strength: t.signal, secure: t.secure, enterprise: t.enterprise, active: t.active, saved: t.saved };
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
                    required property bool enterprise
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
                        : active ? "Connected" : saved ? "Saved" : enterprise ? "Sign-in required" : secure ? "Secured" : "Open"
                    trailingIcon: secure ? "lock" : ""

                    onClicked: {
                        if (isOpen) {
                            root.openSsid = "";
                        } else if (!active && (saved || !secure)) {
                            Wifi.connect(ssid, "", null);
                        } else {
                            root.openSsid = ssid;
                            Qt.callLater(() => (enterprise ? username : password).focusField());
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
                            onClicked: { Wifi.connect(ssid, "", null); root.openSsid = ""; }
                        }
                        PillButton {
                            text: "Forget"
                            kind: "outlined"
                            onClicked: { Wifi.forget(ssid); root.openSsid = ""; }
                        }
                    }

                    // New secured network: a password, or for enterprise
                    // networks a sign-in.
                    property string method: "peap"
                    property bool verify: true
                    property bool domainEdited: false

                    function submit(): void {
                        if (!canConnect) return;
                        Wifi.connect(ssid, password.text, enterprise
                            ? { identity: username.text.trim(), method: method, verify: verify, domain: domain.text.trim() }
                            : null);
                        password.text = "";
                        root.openSsid = "";
                    }
                    readonly property bool canConnect: Wifi.connecting === "" && (enterprise
                        ? username.text.trim() !== "" && password.text !== "" && (!verify || domain.text.trim() !== "")
                        : password.text.length >= 8)

                    ColumnLayout {
                        visible: !active && !saved && secure
                        spacing: 8

                        Field {
                            id: username
                            Layout.fillWidth: true
                            visible: enterprise
                            placeholder: "Username (e.g. name@school.edu)"
                            onAccepted: password.focusField()
                            // The realm (after the @) is usually the domain
                            // of the network's certificate, so it fills the
                            // domain until that's typed over.
                            onEdited: if (!row.domainEdited) domain.text = text.includes("@") ? text.split("@").pop().trim() : ""
                        }

                        RowLayout {
                            spacing: 8

                            Field {
                                id: password
                                Layout.fillWidth: true
                                placeholder: "Password"
                                secret: true
                                onAccepted: row.submit()
                            }
                            PillButton {
                                text: "Connect"
                                kind: "filled"
                                active: row.canConnect
                                onClicked: row.submit()
                            }
                        }

                        // EAP method and the server certificate check. PEAP
                        // and checking against the system's CAs suit most
                        // networks; eduroam often uses TTLS instead.
                        RowLayout {
                            visible: enterprise
                            spacing: 8

                            PillButton {
                                text: "PEAP"
                                kind: row.method === "peap" ? "tonal" : "outlined"
                                onClicked: row.method = "peap"
                            }
                            PillButton {
                                text: "TTLS"
                                kind: row.method === "ttls" ? "tonal" : "outlined"
                                onClicked: row.method = "ttls"
                            }
                            Item { Layout.fillWidth: true }
                            PillButton {
                                icon: row.verify ? "verified_user" : "remove_moderator"
                                text: row.verify ? "Check certificate" : "Don't check"
                                kind: row.verify ? "tonal" : "outlined"
                                onClicked: row.verify = !row.verify
                            }
                        }

                        Field {
                            id: domain
                            Layout.fillWidth: true
                            visible: enterprise && row.verify
                            placeholder: "Certificate domain (e.g. northeastern.edu)"
                            onEdited: row.domainEdited = true
                            onAccepted: row.submit()
                        }

                        Label {
                            Layout.fillWidth: true
                            Layout.leftMargin: 12
                            visible: enterprise && !row.verify
                            text: "Without the check, a fake network with this name could collect your password."
                            wrapMode: Text.Wrap
                            font.pixelSize: 12
                            color: Theme.error
                        }
                    }
                }
            }
        }
    }

    Item { implicitHeight: 4 }
}
