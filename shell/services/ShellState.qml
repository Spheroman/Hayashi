pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: root

    // True while the card is off to the right and the panels are showing.
    property bool panelsOpen: false

    // Locking: from the lock request until a successful unlock. The card
    // slides away first; once it's gone, `sessionLocked` engages the
    // compositor's session lock (ext-session-lock), which looks identical.
    property bool locking: false
    property bool sessionLocked: false

    // Whether the card should be away for any reason.
    readonly property bool overlayOpen: panelsOpen || locking

    function togglePanels(): void {
        if (!locking) panelsOpen = !panelsOpen;
    }

    function lock(): void {
        if (locking) return;
        locking = true;
        panelsOpen = false;
        deadline.restart();
    }

    function unlock(): void {
        sessionLocked = false;
        locking = false;
    }

    // Safety net: if the slide can't happen (no screen capture, say), lock
    // anyway. An idle or before-sleep lock must never be skipped.
    Timer {
        id: deadline
        interval: 600
        onTriggered: if (root.locking) root.sessionLocked = true
    }
}
