pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Wi-Fi through NetworkManager's nmcli.
Singleton {
    id: root

    property bool enabled: false
    // [{ ssid, signal (0-100), secure, active, saved }], connected first, then by signal.
    property var networks: []
    readonly property var active: networks.find(n => n.active) ?? null

    // While true (the Wi-Fi card is open), the list refreshes every 10 s.
    property bool watching: false

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

    // Saved and open networks connect directly; new secured ones need a password.
    function connect(ssid: string, password: string): void {
        error = "";
        connecting = ssid;
        const saved = networks.find(n => n.ssid === ssid)?.saved ?? false;
        connectProc.command = saved && password === ""
            ? ["nmcli", "connection", "up", "id", ssid]
            : ["nmcli", "device", "wifi", "connect", ssid].concat(password !== "" ? ["password", password] : []);
        connectProc.running = true;
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
                    } else if (section === "--scan" && f[1] !== "") {
                        const n = { ssid: f[1], signal: +f[2] || 0, secure: (f[3] ?? "") !== "" && f[3] !== "--", active: f[0] === "*" };
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
        stderr: StdioCollector { id: connectErr }
        onExited: (code, status) => {
            if (code !== 0) {
                const msg = connectErr.text.trim().replace(/^Error:\s*/, "");
                root.error = /secrets were required|password|802-11-wireless-security/i.test(msg)
                    ? "Wrong password, or the network needs one."
                    : msg || "Couldn't connect.";
            }
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
        running: root.watching
        onTriggered: root.refresh()
    }

    Component.onCompleted: refresh()
}
