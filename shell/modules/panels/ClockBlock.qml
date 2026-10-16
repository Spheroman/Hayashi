import Quickshell
import QtQuick
import qs.config
import qs.widgets

Column {
    spacing: 6

    Label {
        text: Qt.formatDateTime(clock.date, "HH:mm")
        font.pixelSize: 76
        font.weight: Font.Light
        font.features: { "tnum": 1 }
    }
    Label {
        text: Qt.formatDateTime(clock.date, "dddd, MMMM d")
        font.pixelSize: 19
        color: Theme.fgSurfaceVariant
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
}
