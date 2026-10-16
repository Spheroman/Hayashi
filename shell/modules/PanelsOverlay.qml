import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.config
import qs.services
import qs.modules.panels
import qs.modules.lock

// Super+Esc. Hyprland can't move windows for us, so this takes a still of the
// screen, shows it on the overlay layer exactly where the card is, and slides
// that off to the right. The panels are laid out underneath and never animate.
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
    property bool away: false
    // Shows the lock layout instead of the panels, from the lock request
    // until the card is home again (so unlocking slides the card back over
    // the lock layout, not the panels).
    property bool lockLook: false

    function lockIfAway(): void {
        if (ShellState.locking && away && !anim.running) ShellState.sessionLocked = true;
    }

    function slide(toAway: bool): void {
        away = toAway;
        anim.stop();
        anim.from = card.x;
        anim.to = toAway ? card.width + Tokens.border : 0;
        anim.duration = toAway ? Tokens.cardExit : Tokens.cardReturn;
        anim.easing.bezierCurve = toAway ? Tokens.exitCurve : Tokens.returnCurve;
        anim.start();
    }

    Connections {
        target: ShellState

        function onOverlayOpenChanged(): void {
            if (ShellState.overlayOpen) {
                if (win.shown) win.slide(true);  // reopened mid-return
                else capture.active = true;      // a fresh still; see onHasContentChanged
            } else if (win.shown) {
                win.slide(false);
            } else {
                capture.active = false;
            }
        }

        function onLockingChanged(): void {
            if (ShellState.locking) {
                win.lockLook = true;
                win.lockIfAway();  // locked from the panel view: the card is already away
            }
        }
    }

    NumberAnimation {
        id: anim
        target: card
        property: "x"
        easing.type: Easing.BezierSpline
        onFinished: {
            if (win.away) {
                win.lockIfAway();
            } else {
                win.shown = false;
                win.lockLook = false;
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
        Keys.onEscapePressed: ShellState.panelsOpen = false

        // The base: the same surface as the frame.
        Rectangle {
            anchors.fill: parent
            color: Theme.surface
        }

        Panels {
            y: Tokens.border
            width: parent.width - Tokens.border
            height: parent.height - 2 * Tokens.border
            visible: !win.lockLook
        }

        LockContent {
            y: Tokens.border
            width: parent.width - Tokens.border
            height: parent.height - 2 * Tokens.border
            visible: win.lockLook
            interactive: false
        }

        // The card. The still includes the frame's rounded corners, which are
        // the same color as the base, so a rectangular clip is enough.
        Item {
            id: card

            y: Tokens.border
            width: parent.width - Tokens.border
            height: parent.height - 2 * Tokens.border
            clip: true

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
                            win.slide(true);
                        } else {
                            capture.active = false;
                        }
                    }
                }
            }
        }
    }
}
