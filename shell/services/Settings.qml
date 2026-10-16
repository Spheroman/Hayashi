pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// User settings changed from the panel view, kept in
// $XDG_STATE_HOME/hayashi-shell/settings.json.
Singleton {
    id: root

    // Idle timings in seconds; 0 means never.
    property int dimAfter: 300
    property int lockAfter: 600
    property int screenOffAfter: 900
    property int suspendAfter: 1800

    property bool loaded: false

    readonly property string dir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/hayashi-shell"

    function save(): void {
        if (!loaded) return;
        store.setText(JSON.stringify({
            idle: { dim: dimAfter, lock: lockAfter, screenOff: screenOffAfter, suspend: suspendAfter },
        }, null, 2));
    }

    onDimAfterChanged: save()
    onLockAfterChanged: save()
    onScreenOffAfterChanged: save()
    onSuspendAfterChanged: save()

    Process {
        running: true
        command: ["mkdir", "-p", root.dir]
    }

    FileView {
        id: store
        path: root.dir + "/settings.json"
        printErrors: false
        onLoaded: {
            try {
                const s = JSON.parse(text()).idle ?? {};
                if (s.dim !== undefined) root.dimAfter = s.dim;
                if (s.lock !== undefined) root.lockAfter = s.lock;
                if (s.screenOff !== undefined) root.screenOffAfter = s.screenOff;
                if (s.suspend !== undefined) root.suspendAfter = s.suspend;
            } catch (e) {
                console.warn("Settings: ignoring unreadable settings.json:", e);
            }
            root.loaded = true;
        }
        onLoadFailed: root.loaded = true
    }
}
