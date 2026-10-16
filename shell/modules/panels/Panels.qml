import QtQuick
import QtQuick.Layouts
import qs.config

// The panel screen under the card. Two columns, like a tablet's pulled-down
// shade in landscape.
Item {
    id: root

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 40
        anchors.rightMargin: 40
        anchors.topMargin: 36
        anchors.bottomMargin: 36
        spacing: 28

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            spacing: 20

            ClockBlock {}
            Tiles { Layout.fillWidth: true }
            Sliders { Layout.fillWidth: true }
            Item { Layout.fillHeight: true }
            Session { Layout.fillWidth: true }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            spacing: 20

            Media { Layout.fillWidth: true }
            Item { Layout.fillHeight: true }
        }
    }
}
