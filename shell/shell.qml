// Hayashi's shell. See README.md for the design; tuned values are in
// config/Tokens.qml.
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.config
import qs.services
import qs.modules
import qs.modules.lock
import qs.modules.notifications

ShellRoot {
    // One set of notification popups, on the first screen.
    NotificationPopups { screen: Quickshell.screens[0] }

    // Idle timers (dim, lock, screen off, sleep); timings are in Settings.
    readonly property bool idleReady: Idle.ready
    // Settings load at startup (they also set apps' dark or light).
    readonly property bool settingsReady: Settings.loaded

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

    // Fast path for keybinds: `hayashi-shell msg panels|launcher|lock|close`
    // writes one word to this socket, which takes a few milliseconds.
    // (`qs ipc` below starts a whole Quickshell process per call, ~45 ms.)
    SocketServer {
        active: true
        path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/hayashi-shell.sock"

        handler: Socket {
            parser: SplitParser {
                onRead: data => {
                    switch (data.trim()) {
                    case "panels": ShellState.togglePanels(); break;
                    case "launcher": ShellState.toggleLauncher(); break;
                    case "lock": ShellState.lock(); break;
                    case "close": ShellState.closeOverlay(); break;
                    default: console.warn("hayashi-shell: unknown message", data);
                    }
                }
            }
        }
    }

    // `hayashi-shell ipc call panels toggle`, for scripts.
    IpcHandler {
        target: "panels"

        function toggle(): void { ShellState.togglePanels(); }
        function open(): void { ShellState.openPanels(); }
        function close(): void { ShellState.closeOverlay(); }
    }

    // `hayashi-shell ipc call launcher toggle`, bound to Super+Space.
    IpcHandler {
        target: "launcher"

        function toggle(): void { ShellState.toggleLauncher(); }
    }

    // `hayashi-shell ipc call lock lock`, used by the idle daemon.
    IpcHandler {
        target: "lock"

        function lock(): void { ShellState.lock(); }
        function isLocked(): bool { return ShellState.locking; }
    }
}
