pragma Singleton

import Quickshell
import Quickshell.Wayland
import QtQuick

// Idle timers (ext-idle-notify), with timings from Settings. Apps that
// inhibit idle (video playback, say) hold them off.
//   dim:        brightness to 10%, restored on activity
//   lock:       the shell's lock screen
//   screen off: outputs powered down (wlr-output-power-management, via wlopm)
//   suspend:    systemctl suspend
Singleton {
    id: root

    readonly property bool ready: true

    IdleMonitor {
        enabled: Settings.dimAfter > 0
        timeout: Math.max(1, Settings.dimAfter)
        onIsIdleChanged: Quickshell.execDetached(isIdle ? ["brightnessctl", "-q", "-s", "set", "10%"] : ["brightnessctl", "-q", "-r"])
    }

    IdleMonitor {
        enabled: Settings.lockAfter > 0
        timeout: Math.max(1, Settings.lockAfter)
        onIsIdleChanged: if (isIdle) ShellState.lock()
    }

    IdleMonitor {
        enabled: Settings.screenOffAfter > 0
        timeout: Math.max(1, Settings.screenOffAfter)
        onIsIdleChanged: Quickshell.execDetached(["wlopm", isIdle ? "--off" : "--on", "*"])
    }

    IdleMonitor {
        enabled: Settings.suspendAfter > 0
        timeout: Math.max(1, Settings.suspendAfter)
        onIsIdleChanged: if (isIdle) Quickshell.execDetached(["systemctl", "suspend"])
    }
}
