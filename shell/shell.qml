// Hayashi's shell. See README.md for the design; tuned values are in
// config/Tokens.qml.
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.services
import qs.modules
import qs.modules.lock
import qs.modules.notifications

ShellRoot {
    // One set of notification popups, on the first screen.
    NotificationPopups { screen: Quickshell.screens[0] }

    Variants {
        model: Quickshell.screens

        Scope {
            id: perScreen

            required property ShellScreen modelData

            Background { screen: perScreen.modelData }
            Frame { screen: perScreen.modelData }
            PanelsOverlay { screen: perScreen.modelData }
        }
    }

    // The real lock (ext-session-lock). It engages once the card has slid
    // away, and its surfaces look exactly like the end of that slide.
    WlSessionLock {
        locked: ShellState.sessionLocked && !Lock.fake

        WlSessionLockSurface {
            color: Theme.surface

            LockScreen {
                id: lockScreen
                anchors.fill: parent
                Component.onCompleted: Qt.callLater(lockScreen.focusField)
            }
        }
    }

    // Development stand-in for the lock; see Lock.fake.
    Variants {
        model: Lock.fake ? Quickshell.screens : []

        PanelWindow {
            id: fakeLock

            required property ShellScreen modelData

            screen: modelData
            visible: ShellState.sessionLocked
            anchors {
                left: true
                right: true
                top: true
                bottom: true
            }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "card-fake-lock"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            LockScreen {
                id: fakeScreen
                anchors.fill: parent
            }
            onVisibleChanged: if (visible) Qt.callLater(fakeScreen.focusField)
        }
    }

    // `hayashi-shell ipc call panels toggle`, bound to Super+Esc.
    IpcHandler {
        target: "panels"

        function toggle(): void { ShellState.togglePanels(); }
        function open(): void { if (!ShellState.locking) ShellState.panelsOpen = true; }
        function close(): void { ShellState.panelsOpen = false; }
    }

    // `hayashi-shell ipc call lock lock`, used by the idle daemon.
    IpcHandler {
        target: "lock"

        function lock(): void { ShellState.lock(); }
        function isLocked(): bool { return ShellState.locking; }
    }
}
