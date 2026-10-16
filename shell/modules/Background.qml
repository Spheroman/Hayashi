import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.config

// The wallpaper: a solid Material tone on the background layer.
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
    color: Theme.wallpaper
}
