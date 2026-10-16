pragma Singleton

import Quickshell
import QtQuick

// Tuned values from the Card and Base prototype (px at 1920x1200).
Singleton {
    // Motion: the card is the only thing that moves.
    // The card leaves on M3's emphasized decelerate: it moves at full speed
    // from the first frame and settles at the end, so opening feels instant.
    // (The tuned prototype value was [0.3, 0, 1, 1], which eases in and
    // barely moves for the first third.)
    readonly property int cardExit: 150
    readonly property var exitCurve: [0.05, 0.7, 0.1, 1, 1, 1]
    readonly property int cardReturn: 150
    readonly property var returnCurve: [0, 0, 0, 1, 1, 1]

    // Frame
    readonly property int barWidth: 54
    readonly property int border: 6
    readonly property int radius: 36
    readonly property int gaps: 12
    // Concentric with the card corner: inner radius = outer radius - margin.
    readonly property int windowRadius: radius - gaps

    // Launcher: how far the card slides to reveal the search column.
    readonly property int launcherWidth: 420

    // Type
    readonly property string fontFamily: "Space Grotesk"
    readonly property string monoFamily: "SpaceMono Nerd Font"
    readonly property string iconFamily: "Material Symbols Rounded"
}
