pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Wi-Fi through NetworkManager's nmcli.
Singleton {
    id: root

    property bool enabled: false
    // [{ ssid, signal (0-100), security, secure, active, saved }], connected first, then by signal.
    property var networks: []
    readonly property var active: networks.find(n => n.active) ?? null

    // While true (the Wi-Fi card is open), the list refreshes every 10 s.
    property bool watching: false
    // While true (a password field is open), the automatic refresh pauses,
    // so the list doesn't reorder under the user.
    property bool paused: false

    property string connecting: ""
    property string error: ""

    function refresh(): void {
        if (!listProc.running) listProc.running = true;
    }

    function setEnabled(on: bool): void {
        enabled = on;
        error = "";
        Quickshell.execDetached(["nmcli", "radio", "wifi", on ? "on" : "off"]);
        refreshSoon.restart();
    }

    // Saved and open networks connect directly. A new secured network never
    // has its password on a command line (where other processes could read
    // it): the network is saved without it, the password goes to a one-off
    // file in $XDG_RUNTIME_DIR (private to the user, in memory) that
    // `nmcli connection up` reads with passwd-file, and the file is deleted
    // as soon as nmcli finishes. A failed attempt also removes the new
    // saved network, so a wrong password doesn't leave a broken one behind.
    function connect(ssid: string, password: string): void {
        error = "";
        connecting = ssid;
        const n = networks.find(x => x.ssid === ssid);

        if (password === "") {
            connectProc.newProfile = "";
            connectProc.command = n?.saved ? ["nmcli", "connection", "up", "id", ssid] : ["nmcli", "device", "wifi", "connect", ssid];
            connectProc.running = true;
            return;
        }

        // WPA3-only networks use SAE; everything else WPA-PSK.
        const sec = n?.security ?? "";
        const keyMgmt = /WPA3/.test(sec) && !/WPA2|WPA1/.test(sec) ? "sae" : "wpa-psk";

        secretFile.path = `${root.runtimeDir}/hayashi-shell-wifi-${Date.now()}`;
        secretFile.setText("802-11-wireless-security.psk:" + password + "\n");

        addProc.ssid = ssid;
        addProc.command = ["nmcli", "connection", "add", "type", "wifi", "con-name", ssid, "ssid", ssid, "wifi-sec.key-mgmt", keyMgmt];
        addProc.running = true;
    }

    readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"

    function removeSecret(): void {
        if (secretFile.path !== "") Quickshell.execDetached(["rm", "-f", secretFile.path]);
    }

    FileView {
        id: secretFile
        // Written before nmcli reads it.
        blockWrites: true
        atomicWrites: false
        printErrors: false
    }

    Process {
        id: addProc

        property string ssid: ""

        stderr: StdioCollector { id: addErr }
        onExited: code => {
            if (code !== 0) {
                root.removeSecret();
                root.error = addErr.text.trim().replace(/^Error:\s*/, "") || "Couldn't save the network.";
                root.connecting = "";
                return;
            }
            connectProc.newProfile = ssid;
            connectProc.command = ["nmcli", "connection", "up", "id", ssid, "passwd-file", secretFile.path];
            connectProc.running = true;
        }
    }

    function disconnect(ssid: string): void {
        Quickshell.execDetached(["nmcli", "connection", "down", "id", ssid]);
        refreshSoon.restart();
    }

    function forget(ssid: string): void {
        Quickshell.execDetached(["nmcli", "connection", "delete", "id", ssid]);
        refreshSoon.restart();
    }

    // nmcli -t escapes ':' inside fields as '\:'.
    function splitTerse(line) {
        const out = [];
        let cur = "";
        for (let i = 0; i < line.length; i++) {
            if (line[i] === "\\" && i + 1 < line.length) { cur += line[++i]; continue; }
            if (line[i] === ":") { out.push(cur); cur = ""; continue; }
            cur += line[i];
        }
        out.push(cur);
        return out;
    }

    Process {
        id: listProc
        command: ["sh", "-c", "nmcli -t -f WIFI general; echo '--saved'; nmcli -t -f NAME,TYPE connection show; echo '--scan'; nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi list --rescan auto"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                root.enabled = lines[0].trim() === "enabled";
                const saved = new Set();
                const bySsid = {};
                let section = "";
                for (const line of lines.slice(1)) {
                    if (line === "--saved" || line === "--scan") { section = line; continue; }
                    if (line.trim() === "") continue;
                    const f = root.splitTerse(line);
                    if (section === "--saved") {
                        if (f[1] === "802-11-wireless") saved.add(f[0]);
                    } else if (section === "--scan" && f.length >= 4 && f[1] !== "") {
                        const n = { ssid: f[1], signal: +f[2] || 0, security: f[3] ?? "", secure: (f[3] ?? "") !== "" && f[3] !== "--", active: f[0] === "*" };
                        const prev = bySsid[n.ssid];
                        if (!prev || n.active || (!prev.active && n.signal > prev.signal)) bySsid[n.ssid] = n;
                    }
                }
                root.networks = Object.values(bySsid)
                    .map(n => Object.assign(n, { saved: saved.has(n.ssid) }))
                    .sort((a, b) => (b.active - a.active) || (b.saved - a.saved) || (b.signal - a.signal));
            }
        }
    }

    Process {
        id: connectProc

        // Set when this attempt created the saved network (new secured network).
        property string newProfile: ""

        stderr: StdioCollector { id: connectErr }
        onExited: (code, status) => {
            if (newProfile !== "") root.removeSecret();
            if (code !== 0) {
                const msg = connectErr.text.trim().replace(/^Error:\s*/, "");
                root.error = /secrets were required|password|802-11-wireless-security/i.test(msg)
                    ? "Wrong password, or the network needs one."
                    : msg || "Couldn't connect.";
                if (newProfile !== "") Quickshell.execDetached(["nmcli", "connection", "delete", "id", newProfile]);
            }
            newProfile = "";
            root.connecting = "";
            root.refresh();
        }
    }

    Timer {
        id: refreshSoon
        interval: 1500
        onTriggered: root.refresh()
    }

    Timer {
        interval: 10000
        repeat: true
        running: root.watching && !root.paused
        onTriggered: root.refresh()
    }

    Component.onCompleted: refresh()
}
