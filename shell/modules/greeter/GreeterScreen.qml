import Quickshell
import Quickshell.Io
import Quickshell.Services.Greetd
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.widgets

// The greeter's layout and its conversation with greetd.
Rectangle {
    id: root

    color: Theme.surface

    // ---- Users and sessions ----

    // People who can log in: [{ name, full }]
    property var users: []
    property int userIndex: 0
    readonly property var user: users[userIndex] ?? null

    // Wayland sessions from .desktop files: [{ name, exec }]
    property var sessions: []
    property int sessionIndex: 0
    readonly property var session: sessions[sessionIndex] ?? null

    Process {
        running: true
        command: ["getent", "passwd"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.users = text.trim().split("\n")
                    .map(l => l.split(":"))
                    .filter(f => +f[2] >= 1000 && +f[2] < 60000 && !/(nologin|false)$/.test(f[6] ?? ""))
                    .map(f => ({ name: f[0], full: (f[4] ?? "").split(",")[0] || f[0] }));
            }
        }
    }

    Process {
        running: true
        // HAYASHI_GREETER_SESSIONS is set by the NixOS module; elsewhere, the
        // usual location.
        command: ["sh", "-c", `dir="\${HAYASHI_GREETER_SESSIONS:-/usr/share/wayland-sessions}"
            for f in "$dir"/*.desktop; do
              [ -e "$f" ] || continue
              name=$(sed -n 's/^Name=//p' "$f" | head -n1)
              exec=$(sed -n 's/^Exec=//p' "$f" | head -n1 | sed 's/ %[a-zA-Z]//g')
              # Skip sessions whose program isn't installed (a .desktop file can outlive it).
              command -v "\${exec%% *}" >/dev/null 2>&1 || continue
              printf '%s\\t%s\\n' "$name" "$exec"
            done`]
        stdout: StdioCollector {
            onStreamFinished: {
                root.sessions = text.trim().split("\n").filter(l => l.includes("\t"))
                    .map(l => ({ name: l.split("\t")[0], exec: l.split("\t")[1] }))
                    // By display name, so "Hyprland" comes before "Hyprland (uwsm-managed)"
                    // (file order depends on the locale, and the greeter's is plain C).
                    .sort((a, b) => a.name.localeCompare(b.name));
            }
        }
    }

    // ---- Talking to greetd ----

    property bool busy: false
    property string status: ""
    property string pending: ""

    // After the password, PAM can ask more (a one-time code, say). While a
    // question is waiting, the field answers it instead of starting over.
    property bool awaiting: false
    property string prompt: ""
    property bool echo: false

    function submit(): void {
        if (busy || !user || !session || field.text === "") return;
        status = "";
        busy = true;
        if (awaiting) {
            awaiting = false;
            Greetd.respond(field.text);
            field.text = "";
            return;
        }
        pending = field.text;
        Greetd.createSession(user.name);
    }

    // The command greetd runs for the session. greetd joins these arguments
    // with plain spaces (no quoting) and runs `exec <joined>` through
    // /bin/sh, so the script is shell-quoted here or it'd be split into
    // words. The session's output goes to the journal (tag
    // hayashi-session) instead of the console, where it would flash up
    // before the compositor takes over the screen.
    // HAYASHI_SHELL_INTRO (passed separately) makes the shell slide the card in.
    function sessionCommand(exec: string): var {
        const quote = s => "'" + s.replace(/'/g, "'\\''") + "'";
        const script = "if command -v systemd-cat >/dev/null 2>&1; "
            + "then exec systemd-cat -t hayashi-session " + exec + "; "
            + "else exec " + exec + "; fi";
        return ["sh", "-c", quote(script)];
    }

    function reset(): void {
        busy = false;
        pending = "";
        awaiting = false;
        prompt = "";
        echo = false;
        field.text = "";
    }

    function fail(message: string): void {
        reset();
        status = message;
        shake.start();
        if (Greetd.state !== GreetdState.Inactive) Greetd.cancelSession();
    }

    Connections {
        target: Greetd

        function onAuthMessage(message: string, error: bool, responseRequired: bool, echoResponse: bool): void {
            if (responseRequired && root.pending !== "") {
                // The first question is the password the user already typed.
                Greetd.respond(root.pending);
                root.pending = "";
            } else if (responseRequired) {
                root.busy = false;
                root.awaiting = true;
                root.prompt = message.replace(/:\s*$/, "");
                root.echo = echoResponse;
                field.text = "";
                field.forceActiveFocus();
            } else if (message !== "") {
                root.status = message;
            }
        }
        function onAuthFailure(message: string): void {
            root.fail("Wrong password. Try again.");
        }
        function onReadyToLaunch(): void {
            Greetd.launch(root.sessionCommand(root.session.exec), ["HAYASHI_SHELL_INTRO=1"]);
        }
        function onError(error: string): void {
            root.fail("Couldn't sign in: " + error);
        }
    }

    // ---- Layout ----

    // Status where the bar is, so it lines up with the session's bar.
    Column {
        x: (Tokens.barWidth - width) / 2
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 14
        spacing: 10

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: UPower.displayDevice.isLaptopBattery
            spacing: 2

            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: UPower.displayDevice.state === UPowerDeviceState.Charging ? "battery_charging_full" : "battery_full"
                color: Theme.fgSurfaceVariant
                size: 20
            }
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                readonly property real p: UPower.displayDevice.percentage
                text: Math.round(p > 1 ? p : p * 100) + "%"
                color: Theme.fgSurfaceVariant
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, "HH") + "\n" + Qt.formatDateTime(clock.date, "mm")
            horizontalAlignment: Text.AlignHCenter
            lineHeight: 0.95
            font.pixelSize: 15
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }
    }

    RowLayout {
        x: Tokens.barWidth + 60
        y: Tokens.border
        width: parent.width - Tokens.barWidth - Tokens.border - 120
        height: parent.height - 2 * Tokens.border
        spacing: 40

        Column {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 16

            Label {
                text: Qt.formatDateTime(clock.date, "HH:mm")
                font.pixelSize: 170
                font.weight: Font.Light
                font.features: { "tnum": 1 }
            }
            Label {
                text: Qt.formatDateTime(clock.date, "dddd, MMMM d")
                font.pixelSize: 24
                color: Theme.fgSurfaceVariant
            }
        }

        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: 440
            implicitHeight: card.implicitHeight + 56
            radius: 32
            color: Theme.surfaceContainer

            ColumnLayout {
                id: card

                anchors.fill: parent
                anchors.margins: 28
                spacing: 16

                // Who's signing in. With one user it's just their name.
                Flow {
                    Layout.fillWidth: true
                    spacing: 10

                    Repeater {
                        model: root.users

                        delegate: Rectangle {
                            id: userChip

                            required property var modelData
                            required property int index
                            readonly property bool selected: index === root.userIndex

                            width: root.users.length === 1 ? card.width : (card.width - 10) / 2
                            height: 64
                            radius: 20
                            color: selected ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                            border.width: selected && root.users.length > 1 ? 2 : 0
                            border.color: Theme.primary

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 12

                                Rectangle {
                                    Layout.preferredWidth: 40
                                    Layout.preferredHeight: 40
                                    radius: 14
                                    color: userChip.index % 2 === 0 ? Theme.primaryContainer : Theme.tertiaryContainer

                                    Label {
                                        anchors.centerIn: parent
                                        text: userChip.modelData.full.charAt(0).toUpperCase()
                                        font.pixelSize: 16
                                        font.weight: Font.Bold
                                        color: userChip.index % 2 === 0 ? Theme.fgPrimaryContainer : Theme.fgTertiaryContainer
                                    }
                                }
                                Label {
                                    Layout.fillWidth: true
                                    text: userChip.modelData.full
                                    font.pixelSize: 15
                                    font.weight: Font.DemiBold
                                }
                            }

                            TapHandler {
                                enabled: !root.busy
                                onTapped: {
                                    root.userIndex = userChip.index;
                                    field.forceActiveFocus();
                                }
                            }
                        }
                    }
                }

                // Password field: the same pill as the lock screen.
                Rectangle {
                    id: pill

                    Layout.fillWidth: true
                    implicitHeight: 52
                    radius: height / 2
                    color: Theme.surfaceContainerHighest
                    border.width: 2
                    border.color: field.activeFocus ? Theme.primary : "transparent"

                    SequentialAnimation {
                        id: shake
                        NumberAnimation { target: pill; property: "x"; to: -8; duration: 45 }
                        NumberAnimation { target: pill; property: "x"; to: 8; duration: 90 }
                        NumberAnimation { target: pill; property: "x"; to: -8; duration: 90 }
                        NumberAnimation { target: pill; property: "x"; to: 0; duration: 45 }
                    }

                    TextInput {
                        id: field

                        anchors.left: parent.left
                        anchors.right: go.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 20
                        anchors.rightMargin: 8
                        enabled: !root.busy
                        focus: true
                        echoMode: root.echo ? TextInput.Normal : TextInput.Password
                        passwordCharacter: "•"
                        color: Theme.fgSurface
                        selectionColor: Theme.primaryContainer
                        font.family: Tokens.fontFamily
                        font.pixelSize: 16
                        clip: true
                        onAccepted: root.submit()
                        Component.onCompleted: forceActiveFocus()

                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: field.text === ""
                            text: root.busy ? "Signing in…" : root.awaiting ? root.prompt : "Password"
                            font.pixelSize: 16
                            color: Theme.fgSurfaceVariant
                        }
                    }

                    Rectangle {
                        id: go

                        anchors.right: parent.right
                        anchors.rightMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        width: 44
                        height: 44
                        radius: 22
                        color: Theme.primary

                        Icon {
                            anchors.centerIn: parent
                            name: root.busy ? "hourglass_empty" : "arrow_forward"
                            size: 20
                            color: Theme.fgPrimary
                        }
                        TapHandler { onTapped: root.submit() }
                    }
                }

                // Session choice, only when there's more than one.
                Flow {
                    Layout.fillWidth: true
                    spacing: 6
                    visible: root.sessions.length > 1

                    Repeater {
                        model: root.sessions

                        delegate: Rectangle {
                            id: sessionChip

                            required property var modelData
                            required property int index
                            readonly property bool selected: index === root.sessionIndex

                            width: sessionLabel.implicitWidth + 24
                            height: 32
                            radius: 10
                            color: selected ? Theme.secondaryContainer : "transparent"
                            border.width: selected ? 0 : 1.5
                            border.color: Theme.outlineVariant

                            Label {
                                id: sessionLabel
                                anchors.centerIn: parent
                                text: sessionChip.modelData.name
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                color: sessionChip.selected ? Theme.fgSecondaryContainer : Theme.fgSurfaceVariant
                            }
                            TapHandler { onTapped: root.sessionIndex = sessionChip.index }
                        }
                    }
                }

                Label {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.status !== "" ? root.status
                        : root.sessions.length === 0 ? "No sessions found to start."
                        : ""
                    wrapMode: Text.Wrap
                    font.pixelSize: 13
                    color: Theme.error
                }
            }
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
}
