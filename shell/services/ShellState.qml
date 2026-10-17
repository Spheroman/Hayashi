pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: root

    // The panel view (Super+Esc): the card slides all the way off.
    property bool panelsOpen: false
    // The launcher (Super+Space): the card slides over just far enough for
    // the search column.
    property bool launcherOpen: false

    // Locking: from the lock request until a successful unlock. The card
    // slides away first; once it's gone, `sessionLocked` engages the
    // compositor's session lock (ext-session-lock), which looks identical.
    property bool locking: false
    property bool sessionLocked: false

    // Login intro: the greeter starts the session with HAYASHI_SHELL_INTRO=1,
    // and the shell opens on the bare base and slides the card in. Until it
    // finishes, everything (wallpaper included) is drawn in the base color,
    // so the first frames match the greeter and Hyprland's background.
    property bool introRunning: Quickshell.env("HAYASHI_SHELL_INTRO") === "1"

    // Whether the card should be away for any reason.
    readonly property bool overlayOpen: panelsOpen || launcherOpen || locking

    // When switching between views, the new one opens before the old one
    // closes, so overlayOpen never dips and the card moves straight across.
    function togglePanels(): void {
        if (locking) return;
        if (panelsOpen) panelsOpen = false;
        else openPanels();
    }
    function openPanels(): void {
        if (locking) return;
        panelsOpen = true;
        launcherOpen = false;
    }
    function toggleLauncher(): void {
        if (locking) return;
        if (launcherOpen) {
            launcherOpen = false;
        } else {
            launcherOpen = true;
            panelsOpen = false;
        }
    }
    function closeOverlay(): void {
        if (locking) return;
        panelsOpen = false;
        launcherOpen = false;
    }

    function lock(): void {
        if (locking) {
            console.info("lock: requested while already locked");
            return;
        }
        console.info("lock: requested at", new Date().toISOString());
        locking = true;
        panelsOpen = false;
        launcherOpen = false;
        deadline.restart();
    }

    function unlock(): void {
        console.info("lock: unlocked at", new Date().toISOString());
        sessionLocked = false;
        locking = false;
    }

    // Logged (with the time) so a lock that misbehaves can be traced in
    // `qs log` afterwards.
    onSessionLockedChanged: console.info("lock: session lock", sessionLocked ? "engaged" : "released", "at", new Date().toISOString())

    // Safety net: if the slide can't happen (no screen capture, say), lock
    // anyway. An idle or before-sleep lock must never be skipped.
    Timer {
        id: deadline
        interval: 600
        onTriggered: if (root.locking) root.sessionLocked = true
    }
}
