import QtQuick
import qs.config
import qs.modules

// A whole lock surface: the base, the bar (which hides its workspaces while
// locked) and the lock layout in the card area. Matches what the panel
// overlay shows at the end of the slide.
Rectangle {
    id: root

    color: Theme.surface

    function focusField(): void {
        content.focusField();
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
        interactive: true
    }
}
