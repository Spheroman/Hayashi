pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.config

// User settings changed from the panel view, kept in
// $XDG_STATE_HOME/hayashi-shell/settings.json.
Singleton {
    id: root

    // Idle timings in seconds; 0 means never.
    property int dimAfter: 300
    property int lockAfter: 600
    property int screenOffAfter: 900
    property int suspendAfter: 1800

    // Dark or light, for the shell and for apps: apps learn it from the desktop
    // portal, which reads GNOME's color-scheme setting, so it's written there
    // too (on every change, and once at startup so apps match the shell).
    property bool dark: true

    property bool loaded: false

    readonly property string dir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/hayashi-shell"

    function save(): void {
        if (!loaded) return;
        store.setText(JSON.stringify({
            idle: { dim: dimAfter, lock: lockAfter, screenOff: screenOffAfter, suspend: suspendAfter },
            appearance: { dark: dark },
        }, null, 2));
    }

    onDimAfterChanged: save()
    onLockAfterChanged: save()
    onScreenOffAfterChanged: save()
    onSuspendAfterChanged: save()
    onDarkChanged: { applyDark(); save(); }

    function applyDark(): void {
        Theme.dark = dark;
        Quickshell.execDetached(["dconf", "write", "/org/gnome/desktop/interface/color-scheme", dark ? "'prefer-dark'" : "'prefer-light'"]);
    }

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
                const all = JSON.parse(text());
                const s = all.idle ?? {};
                if (all.appearance?.dark !== undefined) root.dark = all.appearance.dark;
                if (s.dim !== undefined) root.dimAfter = s.dim;
                if (s.lock !== undefined) root.lockAfter = s.lock;
                if (s.screenOff !== undefined) root.screenOffAfter = s.screenOff;
                if (s.suspend !== undefined) root.suspendAfter = s.suspend;
            } catch (e) {
                console.warn("Settings: ignoring unreadable settings.json:", e);
            }
            root.loaded = true;
            root.applyDark();
        }
        onLoadFailed: { root.loaded = true; root.applyDark(); }
    }
}
