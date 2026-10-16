import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.config
import qs.services
import qs.modules.panels
import qs.modules.lock
import qs.modules.launcher

// Moves the card. Hyprland can't move windows for us, so this takes a still
// of the screen, shows it on the overlay layer exactly where the card is, and
// slides that: all the way off for the panel view and the lock screen, or
// just far enough for the launcher column. What's underneath never animates.
// (On Hayashi, the compositor would slide the real card instead; see issue #5.)
//
// The surface stays mapped all the time, fully transparent and click-through
// while closed. Mapping it on demand would let the compositor run its own
// open animation (Hyprland fades new layers in), which shows up as a double
// exposure during the slide.
PanelWindow {
    id: win

    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "card-panels"
    WlrLayershell.keyboardFocus: ShellState.overlayOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    color: "transparent"
    // Input only while shown, and never over the bar.
    mask: Region { item: inputArea }

    // True from the moment the still is ready until the card is back home.
    property bool shown: false
    // What's laid out under the card: "panels", "launcher" or "lock". It
    // only changes while a view is open, so closing slides the card back over
    // whatever was showing.
    property string look: "panels"

    readonly property real fullX: card.width + Tokens.border

    function targetX(): real {
        if (!ShellState.overlayOpen) return 0;
        return ShellState.launcherOpen ? Tokens.launcherWidth : fullX;
    }

    function updateLook(): void {
        if (ShellState.locking) look = "lock";
        else if (ShellState.launcherOpen) look = "launcher";
        else if (ShellState.panelsOpen) look = "panels";
        if (look === "launcher") launcher.open();
    }

    function slideToTarget(): void {
        const to = targetX();
        const leaving = to > card.x;
        anim.stop();
        anim.from = card.x;
        anim.to = to;
        anim.duration = leaving ? Tokens.cardExit : Tokens.cardReturn;
        anim.easing.bezierCurve = leaving ? Tokens.exitCurve : Tokens.returnCurve;
        anim.start();
    }

    // Engage the real session lock once the card is fully off.
    function lockIfAway(): void {
        if (ShellState.locking && !anim.running && card.x >= fullX - 1) ShellState.sessionLocked = true;
    }

    // Any change of view while shown: update what's underneath and move the
    // card there. Opening from nothing goes through a fresh still first.
    function viewChanged(): void {
        if (ShellState.overlayOpen) {
            updateLook();
            if (shown) slideToTarget();
            else capture.active = true;  // see onHasContentChanged
        } else if (shown) {
            slideToTarget();
        } else {
            capture.active = false;
        }
    }

    Connections {
        target: ShellState

        function onPanelsOpenChanged(): void { win.viewChanged(); }
        function onLauncherOpenChanged(): void { win.viewChanged(); }
        function onLockingChanged(): void {
            win.viewChanged();
            win.lockIfAway();  // locked from the panel view: the card is already off
        }
    }

    NumberAnimation {
        id: anim
        target: card
        property: "x"
        easing.type: Easing.BezierSpline
        onFinished: {
            if (card.x > 0) {
                win.lockIfAway();
            } else {
                win.shown = false;
                capture.active = false;
            }
        }
    }

    Item {
        id: inputArea
        x: Tokens.barWidth
        width: win.shown ? win.width - Tokens.barWidth : 0
        height: win.shown ? win.height : 0
    }

    Item {
        id: content

        x: Tokens.barWidth
        width: win.width - Tokens.barWidth
        height: win.height
        visible: win.shown
        focus: true
        Keys.onEscapePressed: ShellState.closeOverlay()

        // The base: the same surface as the frame.
        Rectangle {
            anchors.fill: parent
            color: Theme.surface
        }

        Panels {
            y: Tokens.border
            width: parent.width - Tokens.border
            height: parent.height - 2 * Tokens.border
            visible: win.look === "panels"
        }

        LockContent {
            y: Tokens.border
            width: parent.width - Tokens.border
            height: parent.height - 2 * Tokens.border
            visible: win.look === "lock"
            interactive: false
        }

        Launcher {
            id: launcher

            y: Tokens.border
            width: Tokens.launcherWidth
            height: parent.height - 2 * Tokens.border
            visible: win.look === "launcher"
        }

        // The card. The still includes the frame's rounded corners, which are
        // the same color as the base, so a rectangular clip is enough.
        Item {
            id: card

            y: Tokens.border
            width: parent.width - Tokens.border
            height: parent.height - 2 * Tokens.border
            clip: true

            // With the launcher open, part of the card is still showing;
            // clicking it closes the launcher.
            TapHandler { onTapped: ShellState.closeOverlay() }

            Loader {
                id: capture
                active: false

                sourceComponent: ScreencopyView {
                    captureSource: win.screen
                    // Live until the first frame arrives, then frozen: a
                    // one-shot capture fails if it's requested before the
                    // capture session is ready. The overlay is transparent
                    // at that point, so it doesn't appear in the still.
                    live: true
                    x: -Tokens.barWidth
                    y: -Tokens.border
                    width: win.width
                    height: win.height

                    onHasContentChanged: {
                        if (!hasContent) return;
                        live = false;
                        if (ShellState.overlayOpen) {
                            card.x = 0;
                            win.shown = true;
                            win.updateLook();
                            win.slideToTarget();
                        } else {
                            capture.active = false;
                        }
                    }
                }
            }
        }
    }
}
