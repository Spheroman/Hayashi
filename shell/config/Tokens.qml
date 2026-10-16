pragma Singleton

import Quickshell
import QtQuick

// Tuned values from the Card and Base prototype (px at 1920x1200).
Singleton {
    // Motion: the card is the only thing that moves.
    readonly property int cardExit: 150
    readonly property var exitCurve: [0.3, 0, 1, 1, 1, 1]
    readonly property int cardReturn: 150
    readonly property var returnCurve: [0, 0, 0, 1, 1, 1]

    // Frame
    readonly property int barWidth: 54
    readonly property int border: 6
    readonly property int radius: 36
    readonly property int gaps: 12
    // Concentric with the card corner: inner radius = outer radius - margin.
    readonly property int windowRadius: radius - gaps

    // Type
    readonly property string fontFamily: "Space Grotesk"
    readonly property string monoFamily: "SpaceMono Nerd Font"
    readonly property string iconFamily: "Material Symbols Rounded"
}
