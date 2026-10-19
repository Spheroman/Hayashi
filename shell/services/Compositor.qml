pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// The one place the shell talks to the compositor. The UI only uses the
// properties and functions in the first block; everything below it is the
// Hyprland backend and is what would be swapped out for Hayashi.
//
// Hyprland 0.56 has no numeric workspace ids and takes Lua for dispatch, which
// Quickshell's built-in Hyprland module predates, so this reads `hyprctl -j`
// and refreshes on any event from Hyprland's event socket.
Singleton {
    id: root

    // ---- Interface ----

    // All workspaces: [{ name, windows }], in a-z, 0-9 order.
    property var workspaces: []
    property string activeName: ""
    readonly property bool activeHasWindows: (workspaces.find(w => w.name === activeName)?.windows ?? 0) > 0
    // What the bar shows: occupied workspaces plus the active one even if empty.
    readonly property var visibleWorkspaces: {
        const list = workspaces.filter(w => w.windows > 0 || w.name === activeName);
        if (activeName !== "" && !list.some(w => w.name === activeName))
            list.push({ name: activeName, windows: 0 });
        return list.sort((a, b) => rank(a.name) - rank(b.name));
    }

    // Every window on every workspace: [{ address, title, appId, workspace }],
    // most recently focused first.
    property var windows: []

    function focusWorkspace(name: string): void {
        Quickshell.execDetached(["hyprctl", "dispatch", `hl.dsp.focus({ workspace = "name:${name}" })`]);
    }
    // Switches to the window's workspace and focuses it.
    function focusWindow(address: string): void {
        Quickshell.execDetached(["hyprctl", "dispatch", `hl.dsp.focus({ window = "address:${address}" })`]);
    }
    // Back to the workspace that was active before this one.
    function focusPreviousWorkspace(): void {
        Quickshell.execDetached(["hyprctl", "dispatch", `hl.dsp.focus({ workspace = "previous" })`]);
    }
    // Window border colors ("rrggbb") for the focused and other windows, from
    // the shell's theme. Kept and re-applied if the compositor reloads its
    // config, which would put its own back.
    property var borderColors: null
    function setBorderColors(active: string, inactive: string): void {
        borderColors = { active, inactive };
        applyBorders();
    }
    function exitSession(): void {
        Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.exit()"]);
    }

    // ---- Hyprland backend ----

    readonly property string order: "abcdefghijklmnopqrstuvwxyz0123456789"
    function rank(name) {
        const i = order.indexOf(name);
        return i < 0 ? order.length + name.charCodeAt(0) : i;
    }

    function refresh() {
        if (wsProc.running) wsProc.pending = true;
        else wsProc.running = true;
        if (activeProc.running) activeProc.pending = true;
        else activeProc.running = true;
        if (clientsProc.running) clientsProc.pending = true;
        else clientsProc.running = true;
    }

    Process {
        id: clientsProc
        property bool pending: false
        command: ["hyprctl", "-j", "clients"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.windows = JSON.parse(text)
                        .filter(c => c.mapped !== false && c.workspace?.name && !c.workspace.name.startsWith("special"))
                        .sort((a, b) => (a.focusHistoryID ?? 0) - (b.focusHistoryID ?? 0))
                        .map(c => ({ address: c.address, title: c.title ?? "", appId: c.class ?? "", workspace: c.workspace.name }));
                } catch (e) {
                    console.warn("Compositor: could not parse windows:", e);
                }
            }
        }
        onExited: if (pending) { pending = false; running = true; }
    }

    Process {
        id: wsProc
        property bool pending: false
        command: ["hyprctl", "-j", "workspaces"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.workspaces = JSON.parse(text)
                        .filter(w => w.type === undefined || w.type === "normal")
                        .map(w => ({ name: w.name, windows: w.windows }))
                        .sort((a, b) => root.rank(a.name) - root.rank(b.name));
                } catch (e) {
                    console.warn("Compositor: could not parse workspaces:", e);
                }
            }
        }
        onExited: if (pending) { pending = false; running = true; }
    }

    Process {
        id: activeProc
        property bool pending: false
        command: ["hyprctl", "-j", "activeworkspace"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.activeName = JSON.parse(text).name ?? "";
                } catch (e) {
                    console.warn("Compositor: could not parse active workspace:", e);
                }
            }
        }
        onExited: if (pending) { pending = false; running = true; }
    }

    // Event names change between Hyprland versions, so any event triggers a
    // (debounced) refresh instead of parsing them.
    Timer {
        id: debounce
        interval: 25
        onTriggered: root.refresh()
    }

    Socket {
        path: `${Quickshell.env("XDG_RUNTIME_DIR")}/hypr/${Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")}/.socket2.sock`
        connected: true
        parser: SplitParser {
            onRead: line => {
                if (line.startsWith("configreloaded>>")) root.applyBorders();
                debounce.restart();
            }
        }
    }

    function applyBorders(): void {
        if (!borderColors) return;
        const c = borderColors;
        Quickshell.execDetached(["hyprctl", "dispatch",
            `function() hl.config({ general = { col = { active_border = "rgba(${c.active}ff)", inactive_border = "rgba(${c.inactive}ff)" } } }) end`]);
    }

    Component.onCompleted: refresh()
}
