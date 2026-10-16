import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Shapes
import qs.config
import qs.services

// The shell surface: everything that isn't the card. The card is a hole cut
// out of it, through which the wallpaper and windows show.
Scope {
    id: root

    required property ShellScreen screen

    ExclusionZone { screen: root.screen; edge: "left"; size: Tokens.barWidth }
    ExclusionZone { screen: root.screen; edge: "top"; size: Tokens.border }
    ExclusionZone { screen: root.screen; edge: "right"; size: Tokens.border }
    ExclusionZone { screen: root.screen; edge: "bottom"; size: Tokens.border }

    PanelWindow {
        id: win

        screen: root.screen
        anchors {
            left: true
            right: true
            top: true
            bottom: true
        }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "card-frame"
        color: "transparent"
        // Only the bar takes input; clicks anywhere else go to the windows.
        mask: Region { item: bar }

        // The shell is everything windows don't cover. With windows on the
        // workspace, the hole is flush with them (the outer margin is shell);
        // an empty workspace shows the whole card.
        property real inset: Compositor.activeHasWindows ? Tokens.gaps : 0
        property real holeRadius: Compositor.activeHasWindows ? Tokens.windowRadius : Tokens.radius
        Behavior on inset {
            NumberAnimation { duration: Tokens.cardReturn; easing.type: Easing.BezierSpline; easing.bezierCurve: Tokens.returnCurve }
        }
        Behavior on holeRadius {
            NumberAnimation { duration: Tokens.cardReturn; easing.type: Easing.BezierSpline; easing.bezierCurve: Tokens.returnCurve }
        }

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: Theme.surface
                strokeWidth: -1
                fillRule: ShapePath.OddEvenFill

                PathRectangle {
                    x: 0
                    y: 0
                    width: win.width
                    height: win.height
                }
                PathRectangle {
                    x: Tokens.barWidth + win.inset
                    y: Tokens.border + win.inset
                    width: win.width - Tokens.barWidth - Tokens.border - 2 * win.inset
                    height: win.height - 2 * Tokens.border - 2 * win.inset
                    radius: win.holeRadius
                }
            }
        }

        Bar {
            id: bar
            width: Tokens.barWidth
            height: win.height
        }
    }
}
