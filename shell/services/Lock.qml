pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import QtQuick

// Password checking for the lock screen, through PAM.
Singleton {
    id: root

    // PAM service file in /etc/pam.d. The NixOS module in this flake creates
    // it; elsewhere, copy your distro's login or swaylock file to that name.
    readonly property string pamService: "hayashi-shell"

    // Development only: HAYASHI_SHELL_FAKE_LOCK=1 draws the lock screen in an
    // ordinary overlay instead of a real session lock, and accepts any
    // non-empty password. Never set it outside testing.
    readonly property bool fake: Quickshell.env("HAYASHI_SHELL_FAKE_LOCK") === "1"

    property bool busy: false
    property string status: ""
    signal failed

    readonly property string userName: Quickshell.env("USER") ?? ""
    property string fullName: userName

    property string pending: ""

    function submit(password: string): void {
        if (busy || password === "") return;
        status = "";
        if (fake) {
            ShellState.unlock();
            return;
        }
        busy = true;
        pending = password;
        pam.start();
    }

    PamContext {
        id: pam

        config: root.pamService
        user: root.userName

        onPamMessage: {
            if (responseRequired) respond(root.pending);
            else if (message !== "") root.status = message;
        }
        onCompleted: result => {
            root.busy = false;
            root.pending = "";
            if (result === PamResult.Success) {
                root.status = "";
                ShellState.unlock();
            } else {
                root.status = result === PamResult.MaxTries ? "Too many attempts. Wait a moment, then try again." : "Wrong password. Try again.";
                root.failed();
            }
        }
        onError: error => {
            root.busy = false;
            root.pending = "";
            root.status = "Couldn't check the password (" + PamError.toString(error) + "). Is /etc/pam.d/" + root.pamService + " set up?";
            root.failed();
        }
    }

    // The display name from the passwd entry, e.g. "Jack Wen".
    Process {
        running: true
        command: ["getent", "passwd", root.userName]
        stdout: StdioCollector {
            onStreamFinished: {
                const gecos = (text.split(":")[4] ?? "").split(",")[0];
                if (gecos !== "") root.fullName = gecos;
            }
        }
    }
}
