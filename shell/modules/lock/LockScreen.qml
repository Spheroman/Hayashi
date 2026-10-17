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
