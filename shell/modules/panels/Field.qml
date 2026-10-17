import QtQuick
import qs.config
import qs.widgets

// A one-line text field: a rounded well with a placeholder, outlined while
// focused.
Rectangle {
    id: root

    property alias text: input.text
    property string placeholder
    property bool secret: false
    signal accepted
    // Typed by the user, as opposed to set from code.
    signal edited

    function focusField(): void { input.forceActiveFocus(); }

    implicitHeight: 40
    radius: 20
    color: Theme.surfaceContainerHighest
    border.width: 2
    border.color: input.activeFocus ? Theme.primary : "transparent"

    TextInput {
        id: input

        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        verticalAlignment: TextInput.AlignVCenter
        echoMode: root.secret ? TextInput.Password : TextInput.Normal
        passwordCharacter: "•"
        color: Theme.fgSurface
        font.family: Tokens.fontFamily
        font.pixelSize: 14
        clip: true
        onAccepted: root.accepted()
        onTextEdited: root.edited()
        activeFocusOnTab: true

        Label {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            visible: input.text === ""
            text: root.placeholder
            elide: Text.ElideRight
            font.pixelSize: 14
            color: Theme.fgSurfaceVariant
        }
    }
}
