import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.config
import qs.services

// The wallpaper: a solid Material tone on the background layer. During the
// login intro it's the base color, so nothing shows before the card arrives.
PanelWindow {
    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "card-wallpaper"
    color: ShellState.introRunning ? Theme.surface : Theme.wallpaper
}
