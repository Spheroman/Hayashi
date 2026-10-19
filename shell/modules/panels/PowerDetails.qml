import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.widgets

// Power card: the power profile, battery status and health, the charge
// limit, and the idle timings.
ColumnLayout {
    id: root

    spacing: 6

    // ---- Battery, from sysfs ----

    property int capacity: 0
    property string status: ""
    property real health: 0
    property int cycles: 0
    property bool hasBattery: false
    property bool chargeLimit: false
    property bool chargeLimitAvailable: false
    property bool chargeLimitWritable: false

    Process {
        id: readBattery
        running: true
        command: ["sh", "-c", `b=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -n1)
            [ -n "$b" ] || exit 0
            echo "capacity=$(cat $b/capacity)"; echo "status=$(cat $b/status)"
            echo "full=$(cat $b/energy_full 2>/dev/null || cat $b/charge_full 2>/dev/null)"
            echo "design=$(cat $b/energy_full_design 2>/dev/null || cat $b/charge_full_design 2>/dev/null)"
            echo "cycles=$(cat $b/cycle_count 2>/dev/null)"
            echo "types=$(cat $b/charge_types 2>/dev/null)"
            [ -w $b/charge_types ] && echo writable=1`]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = {};
                for (const l of text.trim().split("\n")) {
                    const i = l.indexOf("=");
                    if (i > 0) v[l.slice(0, i)] = l.slice(i + 1);
                }
                root.hasBattery = v.capacity !== undefined;
                root.capacity = +v.capacity || 0;
                root.status = v.status ?? "";
                root.health = v.full && v.design ? +v.full / +v.design : 0;
                root.cycles = +v.cycles || 0;
                root.chargeLimitAvailable = (v.types ?? "").includes("Long_Life");
                root.chargeLimit = (v.types ?? "").includes("[Long_Life]");
                root.chargeLimitWritable = v.writable === "1";
            }
        }
    }
    Timer {
        interval: 30000
        repeat: true
        running: true
        onTriggered: readBattery.running = true
    }

    function setChargeLimit(on: bool): void {
        Quickshell.execDetached(["sh", "-c", `b=$(ls -d /sys/class/power_supply/BAT* | head -n1); echo ${on ? "Long_Life" : "Standard"} > $b/charge_types`]);
        chargeLimit = on;
        recheck.restart();
    }
    Timer {
        id: recheck
        interval: 800
        onTriggered: readBattery.running = true
    }

    function duration(seconds) {
        if (!seconds || seconds <= 0) return "";
        const h = Math.floor(seconds / 3600), m = Math.round((seconds % 3600) / 60);
        return h > 0 ? `${h} h ${m} min` : `${m} min`;
    }

    // ---- Profile ----

    Label {
        Layout.leftMargin: 4
        text: "PROFILE"
        font.pixelSize: 12
        font.weight: Font.DemiBold
        font.letterSpacing: 0.8
        color: Theme.fgSurfaceVariant
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 2

        Repeater {
            id: profiles
            model: [
                { p: PowerProfile.PowerSaver, label: "Power saver", icon: "eco" },
                { p: PowerProfile.Balanced, label: "Balanced", icon: "speed" },
            ].concat(PowerProfiles.hasPerformanceProfile ? [{ p: PowerProfile.Performance, label: "Performance", icon: "bolt" }] : [])

            delegate: Rectangle {
                required property var modelData
                required property int index
                readonly property bool current: PowerProfiles.profile === modelData.p

                Layout.fillWidth: true
                implicitHeight: 44
                // A connected button group: the ends are round, the joins small.
                topLeftRadius: index === 0 ? 22 : 8
                bottomLeftRadius: index === 0 ? 22 : 8
                topRightRadius: index === profiles.count - 1 ? 22 : 8
                bottomRightRadius: index === profiles.count - 1 ? 22 : 8
                color: current ? Theme.secondaryContainer : Theme.surfaceContainerHigh

                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: modelData.icon
                        size: 18
                        filled: current
                        color: current ? Theme.fgSecondaryContainer : Theme.fgSurface
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        color: current ? Theme.fgSecondaryContainer : Theme.fgSurface
                    }
                }
                TapHandler { onTapped: PowerProfiles.profile = modelData.p }
            }
        }
    }

    DetailRow {
        Layout.fillWidth: true
        Layout.topMargin: 4
        visible: Backpack.available
        icon: "backpack"
        iconFilled: Backpack.active
        selected: Backpack.active
        title: "Backpack mode"
        subtitle: Backpack.switching ? (Backpack.active ? "Turning on…" : "Turning off…")
            : Backpack.active ? "On: no sleep, runs slow and cool; the lid locks"
            : "Keep working with the lid closed, in a bag"
        onClicked: if (!Backpack.switching) Backpack.setActive(!Backpack.active)
    }

    // ---- Battery ----

    Label {
        Layout.leftMargin: 4
        Layout.topMargin: 6
        visible: root.hasBattery
        text: "BATTERY"
        font.pixelSize: 12
        font.weight: Font.DemiBold
        font.letterSpacing: 0.8
        color: Theme.fgSurfaceVariant
    }
    DetailRow {
        Layout.fillWidth: true
        visible: root.hasBattery
        icon: root.status === "Charging" ? "battery_charging_full" : "battery_full"
        title: root.capacity + "% · " + (root.status === "Not charging" ? "Plugged in, not charging" : root.status)
        subtitle: {
            const d = UPower.displayDevice;
            const left = root.status === "Charging" ? root.duration(d.timeToFull) : root.duration(d.timeToEmpty);
            const parts = [];
            if (left) parts.push(left + (root.status === "Charging" ? " until full" : " left"));
            if (root.health > 0) parts.push("Health " + Math.round(root.health * 100) + "%");
            if (root.cycles > 0) parts.push(root.cycles + " cycles");
            return parts.join(" · ");
        }
    }
    DetailRow {
        Layout.fillWidth: true
        visible: root.chargeLimitAvailable
        icon: "eco"
        iconFilled: root.chargeLimit
        selected: root.chargeLimit
        title: "Limit charging"
        subtitle: !root.chargeLimitWritable ? "Needs write access to the battery's charge_types"
            : root.chargeLimit ? "On: stops early to extend battery life" : "Off: charges to 100%"
        onClicked: if (root.chargeLimitWritable) root.setChargeLimit(!root.chargeLimit)
    }

    // ---- Idle ----

    Label {
        Layout.leftMargin: 4
        Layout.topMargin: 6
        text: "WHEN IDLE"
        font.pixelSize: 12
        font.weight: Font.DemiBold
        font.letterSpacing: 0.8
        color: Theme.fgSurfaceVariant
    }

    component IdleRow: RowLayout {
        id: idleRow

        property string label
        property string icon
        property int value
        signal picked(int value)

        readonly property var steps: [60, 120, 300, 600, 900, 1800, 3600, 0]
        function fmt(s) { return s === 0 ? "Never" : s < 3600 ? (s / 60) + " min" : (s / 3600) + " h"; }
        function step(dir) {
            let i = steps.indexOf(value);
            if (i < 0) i = steps.findIndex(s => s === 0 || s > value);
            picked(steps[Math.max(0, Math.min(steps.length - 1, i + dir))]);
        }

        Layout.fillWidth: true
        Layout.leftMargin: 12
        spacing: 12

        Icon { name: idleRow.icon; color: Theme.fgSurface }
        Label {
            Layout.fillWidth: true
            text: idleRow.label
            font.weight: Font.DemiBold
        }
        Rectangle {
            implicitWidth: 150
            implicitHeight: 36
            radius: 18
            color: Theme.surfaceContainerHigh

            RowLayout {
                anchors.fill: parent
                spacing: 0

                Icon {
                    Layout.preferredWidth: 36
                    name: "chevron_left"
                    color: Theme.fgSurfaceVariant
                    TapHandler { onTapped: idleRow.step(-1) }
                }
                Label {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: idleRow.fmt(idleRow.value)
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                }
                Icon {
                    Layout.preferredWidth: 36
                    name: "chevron_right"
                    color: Theme.fgSurfaceVariant
                    TapHandler { onTapped: idleRow.step(1) }
                }
            }
        }
    }

    IdleRow { label: "Dim the screen"; icon: "brightness_low"; value: Settings.dimAfter; onPicked: v => Settings.dimAfter = v }
    IdleRow { label: "Lock"; icon: "lock"; value: Settings.lockAfter; onPicked: v => Settings.lockAfter = v }
    IdleRow { label: "Turn off the screen"; icon: "desktop_access_disabled"; value: Settings.screenOffAfter; onPicked: v => Settings.screenOffAfter = v }
    IdleRow { label: "Sleep"; icon: "bedtime"; value: Settings.suspendAfter; onPicked: v => Settings.suspendAfter = v }

    Item { implicitHeight: 8 }
}
