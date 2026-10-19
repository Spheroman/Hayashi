import QtQuick
import qs.config
import qs.services
import qs.modules
import qs.modules.panels

// A whole lock surface: the base, the bar (which hides its workspaces while
// locked) and the lock layout in the card area. Matches what the panel
// overlay shows at the end of the slide.
//
// The bar's clock button or Super+Esc swaps the lock layout for a restricted
// panel view (ShellState.lockPanels): quick toggles, sliders, media,
// notifications and power, nothing that needs the password. Esc, or the
// button again, goes back to the password field.
Rectangle {
    id: root

    color: Theme.surface

    function focusField(): void {
        content.focusField();
    }

    Connections {
        target: ShellState
        function onLockPanelsChanged(): void {
            if (ShellState.lockPanels) panels.forceActiveFocus();
            else root.focusField();
        }
        function onScreensWoke(): void { redraw.begin(); }
    }

    // After the screens come back on, Hyprland waits for the lock surface's
    // next frame, and a still lock screen sends none: after a second it
    // showed its "lock screen died" error instead (2026-10-18, lid opening
    // in backpack mode). So for a few seconds this pixel (black at 1/255,
    // invisible) toggles, which makes the surface draw new frames while the
    // output comes back up (its modeset takes ~2 s).
    Rectangle {
        id: nudge
        width: 1
        height: 1
        z: 1
        color: "#01000000"
        visible: false
    }
    Timer {
        id: redraw

        property int ticks: 0
        function begin(): void { ticks = 0; restart(); }

        interval: 50
        repeat: true
        onTriggered: {
            nudge.visible = !nudge.visible;
            if (++ticks >= 100) {
                stop();
                nudge.visible = false;
            }
        }
    }

    Bar {
        width: Tokens.barWidth
        height: parent.height
    }

    LockContent {
        id: content

        x: Tokens.barWidth
        y: Tokens.border
        width: parent.width - Tokens.barWidth - Tokens.border
        height: parent.height - 2 * Tokens.border
        visible: !ShellState.lockPanels
        interactive: !ShellState.lockPanels
    }

    Panels {
        id: panels

        x: Tokens.barWidth
        y: Tokens.border
        width: parent.width - Tokens.barWidth - Tokens.border
        height: parent.height - 2 * Tokens.border
        visible: ShellState.lockPanels
        restricted: true
        Keys.onEscapePressed: ShellState.lockPanels = false
    }
}
