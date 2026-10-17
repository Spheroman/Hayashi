import QtQuick
import qs.config

// The card a tile's arrow opens, below that tile's row. It grows open and
// shrinks closed (keeping its content until it's fully closed), and follows
// its content's height as that changes.
Rectangle {
    id: root

    // The component to show, or null when closed.
    property Component content: null
    // What's actually loaded: lags `content` while closing, so the card
    // doesn't empty before it has shrunk away.
    property Component shown: null

    onContentChanged: if (content !== null) shown = content

    radius: 28
    color: Theme.surfaceContainer
    clip: true
    height: content !== null && loader.item ? loader.item.implicitHeight + 24 : 0
    visible: height > 0.5

    Behavior on height {
        NumberAnimation { duration: 220; easing.type: Easing.BezierSpline; easing.bezierCurve: Tokens.returnCurve }
    }
    onHeightChanged: if (height === 0 && content === null) shown = null

    Loader {
        id: loader

        x: 16
        y: 12
        width: parent.width - 32
        sourceComponent: root.shown
    }
}
