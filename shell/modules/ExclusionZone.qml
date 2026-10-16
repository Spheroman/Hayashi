import Quickshell
import Quickshell.Wayland
import QtQuick

// An invisible surface that reserves space along one edge. A layer surface can
// only reserve the edge it's anchored to, so the frame uses one per edge.
PanelWindow {
    property string edge: "left"
    property int size: 0

    anchors {
        left: edge !== "right"
        right: edge !== "left"
        top: edge !== "bottom"
        bottom: edge !== "top"
    }
    implicitWidth: 1
    implicitHeight: 1
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: size
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "card-exclusion"
    color: "transparent"
    mask: Region {}
}
