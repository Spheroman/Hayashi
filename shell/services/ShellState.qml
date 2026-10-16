pragma Singleton

import Quickshell
import QtQuick

Singleton {
    // True while the card is off to the right and the panels are showing.
    property bool panelsOpen: false

    function togglePanels(): void {
        panelsOpen = !panelsOpen;
    }
}
