pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Backpack mode: the laptop keeps working in a bag. The NixOS module's
// hayashi-shell-backpack service does the system side (no sleep, even with
// the lid closed; with it closed, CPU and GPU capped and the fans quiet;
// off again when the battery runs low).
// The shell adds what a closed lid would otherwise have done: it locks, and
// turns the screen off once locked.
Singleton {
    id: root

    readonly property string unit: "hayashi-shell-backpack.service"

    // Whether this system has the service (programs.hayashi-shell.backpackMode).
    property bool available: false
    property bool active: false
    // Between a switch and the service reaching its new state.
    property bool switching: false
    property bool lidClosed: false

    function setActive(on: bool): void {
        switching = true;
        active = on;
        Quickshell.execDetached(["systemctl", on ? "start" : "stop", "--no-block", unit]);
        recheck.restart();
        // Back to normal: whatever the lid did to the screen is undone.
        if (!on) screens(true);
    }

    // Screens off and on (wlr-output-power-management). Coming back on, the
    // lock surface is told to redraw (ShellState.screensWoke).
    function screens(on: bool): void {
        Quickshell.execDetached(["wlopm", on ? "--on" : "--off", "*"]);
        if (on) ShellState.screensWoke();
    }

    // The service's state, and while it's on the lid's.
    Process {
        id: poll
        command: ["sh", "-c", `systemctl show -P LoadState,ActiveState ${root.unit}; cat /proc/acpi/button/lid/*/state 2>/dev/null | head -n1`]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.split("\n");
                root.available = l[0] === "loaded";
                const wasActive = root.active;
                root.active = l[1] === "active" || l[1] === "activating";
                root.switching = false;
                if (wasActive && !root.active) root.screens(true);  // ended itself (low battery)
                const closed = root.active && /closed/.test(l[2] ?? "");
                if (closed !== root.lidClosed) {
                    root.lidClosed = closed;
                    if (closed) ShellState.lock();
                    else root.screens(true);
                }
            }
        }
    }
    Timer {
        running: true
        repeat: true
        triggeredOnStart: true
        interval: root.active ? 2000 : 30000
        onTriggered: poll.running = true
    }
    Timer {
        id: recheck
        interval: 1000
        onTriggered: poll.running = true
    }

    // Screen off once the lock screen is up, so the lock's slide still has
    // a screen to run on.
    Connections {
        target: ShellState
        function onSessionLockedChanged(): void {
            if (root.lidClosed && ShellState.sessionLocked) root.screens(false);
        }
    }
    onLidClosedChanged: if (lidClosed && ShellState.sessionLocked) screens(false)
}
