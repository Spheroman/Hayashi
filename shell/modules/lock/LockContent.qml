import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.widgets

// The lock layout inside the card area: a big clock on the left, the sign-in
// card on the right. Drawn by the real lock surface (interactive) and by the
// panel overlay while the card slides (not interactive), so the handover
// between them is invisible.
Item {
    id: root

    property bool interactive: false

    function focusField(): void {
        field.forceActiveFocus();
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 60
        anchors.rightMargin: 60
        spacing: 40

        Column {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 16

            Label {
                text: Qt.formatDateTime(clock.date, "HH:mm")
                font.pixelSize: 170
                font.weight: Font.Light
                font.features: { "tnum": 1 }
            }
            Label {
                text: Qt.formatDateTime(clock.date, "dddd, MMMM d")
                font.pixelSize: 24
                color: Theme.fgSurfaceVariant
            }
        }

        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: 440
            implicitHeight: card.implicitHeight + 56
            radius: 32
            color: Theme.surfaceContainer

            ColumnLayout {
                id: card

                anchors.fill: parent
                anchors.margins: 28
                spacing: 16

                RowLayout {
                    spacing: 14

                    Rectangle {
                        Layout.preferredWidth: 56
                        Layout.preferredHeight: 56
                        radius: 18
                        color: Theme.primaryContainer

                        Label {
                            anchors.centerIn: parent
                            text: Lock.fullName.charAt(0).toUpperCase()
                            font.pixelSize: 22
                            font.weight: Font.Bold
                            color: Theme.fgPrimaryContainer
                        }
                    }
                    ColumnLayout {
                        spacing: 0

                        Label {
                            text: Lock.fullName
                            font.pixelSize: 18
                            font.weight: Font.DemiBold
                        }
                        Label {
                            text: Notifications.count === 0 ? "Locked"
                                : "Locked · " + Notifications.count + (Notifications.count === 1 ? " notification" : " notifications")
                            font.pixelSize: 13
                            color: Theme.fgSurfaceVariant
                        }
                    }
                }

                // Password field: a pill with a submit button.
                Rectangle {
                    id: pill

                    Layout.fillWidth: true
                    implicitHeight: 52
                    radius: height / 2
                    color: Theme.surfaceContainerHighest
                    border.width: 2
                    border.color: field.activeFocus ? Theme.primary : "transparent"

                    SequentialAnimation {
                        id: shake
                        NumberAnimation { target: pill; property: "x"; to: -8; duration: 45 }
                        NumberAnimation { target: pill; property: "x"; to: 8; duration: 90 }
                        NumberAnimation { target: pill; property: "x"; to: -8; duration: 90 }
                        NumberAnimation { target: pill; property: "x"; to: 0; duration: 45 }
                    }
                    Connections {
                        target: Lock
                        function onFailed(): void {
                            field.text = "";
                            shake.start();
                        }
                    }

                    TextInput {
                        id: field

                        anchors.left: parent.left
                        anchors.right: submit.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 20
                        anchors.rightMargin: 8
                        enabled: root.interactive && !Lock.busy
                        echoMode: TextInput.Password
                        passwordCharacter: "•"
                        color: Theme.fgSurface
                        selectionColor: Theme.primaryContainer
                        font.family: Tokens.fontFamily
                        font.pixelSize: 16
                        clip: true
                        onAccepted: Lock.submit(text)

                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: field.text === ""
                            text: Lock.busy ? "Checking…" : "Password"
                            font.pixelSize: 16
                            color: Theme.fgSurfaceVariant
                        }
                    }

                    Rectangle {
                        id: submit

                        anchors.right: parent.right
                        anchors.rightMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        width: 44
                        height: 44
                        radius: 22
                        color: Theme.primary

                        Icon {
                            anchors.centerIn: parent
                            name: Lock.busy ? "hourglass_empty" : "arrow_forward"
                            size: 20
                            color: Theme.fgPrimary
                        }
                        TapHandler {
                            enabled: root.interactive
                            onTapped: Lock.submit(field.text)
                        }
                    }
                }

                Label {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: Lock.status
                    wrapMode: Text.Wrap
                    font.pixelSize: 13
                    color: Theme.error
                }
            }
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
}
