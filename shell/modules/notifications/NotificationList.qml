import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.widgets

// The notification list on the panel view: a header with Clear all, then the
// notifications, newest first. The first and last items take the large
// radius and the ones between a small one, so the stack reads as one group.
ColumnLayout {
    id: root

    spacing: 6

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 4

        Label {
            Layout.fillWidth: true
            text: "Notifications"
            font.pixelSize: 15
            font.weight: Font.DemiBold
        }
        Rectangle {
            visible: Notifications.count > 0
            implicitWidth: clearLabel.implicitWidth + 24
            implicitHeight: 30
            radius: 15
            color: Theme.surfaceContainerHigh

            Label {
                id: clearLabel
                anchors.centerIn: parent
                text: "Clear all"
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }
            TapHandler { onTapped: Notifications.clearAll() }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        visible: Notifications.count === 0
        implicitHeight: 56
        radius: 24
        color: Theme.surfaceContainer

        Label {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 18
            text: Notifications.dnd ? "No notifications. Do not disturb is on." : "No notifications"
            font.pixelSize: 13
            color: Theme.fgSurfaceVariant
        }
    }

    ListView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        // Always laid out (empty when there are none), so it takes the
        // remaining height and the header stays at the top.
        clip: true
        spacing: 4
        boundsBehavior: Flickable.StopAtBounds
        model: Notifications.list

        delegate: NotificationCard {
            required property var modelData
            required property int index
            entry: modelData
            width: ListView.view.width
            radius: 8
            topLeftRadius: index === 0 ? 24 : 8
            topRightRadius: index === 0 ? 24 : 8
            bottomLeftRadius: index === Notifications.count - 1 ? 24 : 8
            bottomRightRadius: index === Notifications.count - 1 ? 24 : 8
        }
    }
}
