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

    // The theme: dark or light, and the seed hue the palette is built from.
    // They apply to the shell and, as far as each allows, to apps:
    //   - dark/light to GTK/portal apps (GNOME's color-scheme in dconf) and to
    //     foot (SIGUSR1/SIGUSR2 switch its [colors-dark]/[colors-light]);
    //   - the seed to foot windows opened from now on (overrides read by
    //     hayashi-footclient; foot can't reload its config) and to the
    //     compositor's window borders.
    // Re-applied at startup so everything matches the shell.
    property bool dark: true
    property real seedHue: 160

    property bool loaded: false

    readonly property string dir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/hayashi-shell"

    function save(): void {
        if (!loaded) return;
        store.setText(JSON.stringify({
            idle: { dim: dimAfter, lock: lockAfter, screenOff: screenOffAfter, suspend: suspendAfter },
            appearance: { dark: dark, seedHue: seedHue },
        }, null, 2));
    }

    onDimAfterChanged: save()
    onLockAfterChanged: save()
    onScreenOffAfterChanged: save()
    onSuspendAfterChanged: save()
    // The shell follows at once (even mid-drag); everything outside it, and
    // the file, once the value settles.
    onDarkChanged: { Theme.dark = dark; applySoon.restart(); }
    onSeedHueChanged: { Theme.seedHue = seedHue; applySoon.restart(); }

    Timer {
        id: applySoon
        interval: 250
        onTriggered: { root.applyOutside(); root.save(); }
    }

    function applyOutside(): void {
        Quickshell.execDetached(["dconf", "write", "/org/gnome/desktop/interface/color-scheme", dark ? "'prefer-dark'" : "'prefer-light'"]);
        Quickshell.execDetached(["pkill", dark ? "-USR1" : "-USR2", "-x", "foot|footclient"]);
        Compositor.setBorderColors(Theme.hex("primary", dark), Theme.hex("outlineVariant", dark));

        // foot overrides, one per line, for both themes.
        const lines = [];
        for (const [section, d] of [["colors-dark", true], ["colors-light", false]]) {
            const c = name => Theme.hex(name, d);
            lines.push(`${section}.background=${c("surfaceContainerLow")}`,
                `${section}.foreground=${c("fgSurface")}`,
                `${section}.selection-background=${c("primaryContainer")}`,
                `${section}.selection-foreground=${c("fgSurface")}`,
                `${section}.regular0=${d ? c("surfaceContainerHighest") : c("fgSurface")}`,
                `${section}.bright0=${c("outline")}`);
            if (!d) lines.push(`${section}.regular7=${c("surfaceContainerHighest")}`);
        }
        footOverrides.setText(lines.join("\n") + "\n");
    }

    FileView {
        id: footOverrides
        path: root.dir + "/foot-overrides"
        printErrors: false
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
                if (all.appearance?.seedHue !== undefined) root.seedHue = all.appearance.seedHue;
                if (s.dim !== undefined) root.dimAfter = s.dim;
                if (s.lock !== undefined) root.lockAfter = s.lock;
                if (s.screenOff !== undefined) root.screenOffAfter = s.screenOff;
                if (s.suspend !== undefined) root.suspendAfter = s.suspend;
            } catch (e) {
                console.warn("Settings: ignoring unreadable settings.json:", e);
            }
            root.loaded = true;
            root.applyOutside();
        }
        onLoadFailed: { root.loaded = true; root.applyOutside(); }
    }
}
