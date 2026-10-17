import Quickshell
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.widgets

// One notification, used both as a popup and in the panel list.
Rectangle {
    id: root

    required property var entry
    property bool popup: false

    readonly property var n: entry.n
    readonly property bool critical: n.urgency === NotificationUrgency.Critical

    implicitHeight: body.implicitHeight + 28
    color: popup ? Theme.surfaceContainerHigh : Theme.surfaceContainer
    border.width: critical ? 2 : 0
    border.color: Theme.error

    // Popups hide themselves after the sender's timeout (5 s by default).
    // Hovering pauses that; critical ones stay until dismissed.
    Timer {
        running: root.popup && !root.critical && !hover.hovered
        interval: {
            const t = root.n.expireTimeout;
            // Seconds or milliseconds depending on the sender; treat small values as seconds.
            return t <= 0 ? 5000 : t < 100 ? t * 1000 : t;
        }
        onTriggered: Notifications.hidePopup(root.n)
    }

    HoverHandler { id: hover }
    // Opening a notification or using its actions runs the app's handler,
    // so not from behind the lock screen; dismissing still works.
    TapHandler { enabled: !ShellState.locking; onTapped: Notifications.activate(root.n) }

    RowLayout {
        id: body

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 14
        spacing: 12

        // App icon or image, falling back to the app's initial.
        Rectangle {
            Layout.alignment: Qt.AlignTop
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            radius: 20
            color: Theme.primaryContainer
            clip: true

            Image {
                id: icon
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(80, 80)
                source: root.n.image !== "" ? root.n.image
                      : root.n.appIcon !== "" ? Quickshell.iconPath(root.n.appIcon, true)
                      : ""
                visible: status === Image.Ready
            }
            Label {
                anchors.centerIn: parent
                visible: !icon.visible
                text: (root.n.appName || "?").charAt(0).toUpperCase()
                font.pixelSize: 16
                font.weight: Font.Bold
                color: Theme.fgPrimaryContainer
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Label {
                    Layout.fillWidth: true
                    text: root.n.appName + "  ·  " + ago
                    font.pixelSize: 12
                    color: Theme.fgSurfaceVariant

                    readonly property string ago: {
                        clock.date;  // re-evaluate every minute
                        const mins = Math.floor((Date.now() - root.entry.time.getTime()) / 60000);
                        return mins < 1 ? "now" : mins < 60 ? mins + "m" : Math.floor(mins / 60) + "h";
                    }
                }
                Icon {
                    name: "close"
                    size: 18
                    color: Theme.fgSurfaceVariant
                    TapHandler { onTapped: Notifications.dismiss(root.n) }
                }
            }

            Label {
                Layout.fillWidth: true
                text: root.n.summary
                font.pixelSize: 14
                font.weight: Font.DemiBold
                wrapMode: Text.Wrap
                maximumLineCount: 2
            }
            Label {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.n.body
                textFormat: Text.StyledText
                font.pixelSize: 13
                color: Theme.fgSurfaceVariant
                wrapMode: Text.Wrap
                maximumLineCount: root.popup ? 3 : 6
            }

            // Actions other than the default one (which is the tap itself).
            Flow {
                Layout.fillWidth: true
                Layout.topMargin: 6
                spacing: 6
                visible: actions.count > 0 && !ShellState.locking

                Repeater {
                    id: actions
                    model: Array.from(root.n.actions).filter(a => a.identifier !== "default")

                    delegate: Rectangle {
                        required property var modelData
                        width: actionLabel.implicitWidth + 24
                        height: 32
                        radius: 16
                        color: Theme.secondaryContainer

                        Label {
                            id: actionLabel
                            anchors.centerIn: parent
                            text: parent.modelData.text
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            color: Theme.fgSecondaryContainer
                        }
                        TapHandler { onTapped: parent.modelData.invoke() }
                    }
                }
            }
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
}
