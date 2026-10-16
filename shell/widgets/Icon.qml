import QtQuick
import qs.config

// A Material Symbols glyph, by name (the font maps names to glyphs).
Text {
    property string name
    property bool filled: false
    property int size: 22

    text: name
    font.family: Tokens.iconFamily
    font.pixelSize: size
    font.variableAxes: ({ "FILL": filled ? 1 : 0, "opsz": 24 })
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
}
