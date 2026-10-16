import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.widgets

// The launcher column on the base, revealed when the card slides over by
// Tokens.launcherWidth. One search finds three kinds of result:
//   - a calculator line when the query is arithmetic (Enter copies it)
//   - open windows on any workspace (Enter jumps to the window)
//   - apps from .desktop files (Enter launches; recent ones come first)
Item {
    id: root

    property string query: ""
    property int selected: 0

    // Called by the overlay when the launcher opens.
    function open(): void {
        field.text = "";
        query = "";
        selected = 0;
        field.forceActiveFocus();
    }

    // ---- Matching ----

    function score(fields, q) {
        let best = 0;
        for (const raw of fields) {
            const s = (raw ?? "").toLowerCase();
            if (s === "") continue;
            if (s.startsWith(q)) best = Math.max(best, 3);
            else if (s.split(/[\s\-_.]+/).some(w => w.startsWith(q))) best = Math.max(best, 2);
            else if (s.includes(q)) best = Math.max(best, 1);
        }
        return best;
    }

    // Arithmetic only: digits, operators, parentheses, and ^ for powers.
    function calculate(q) {
        if (!/^[\d\s+\-*/().%^]+$/.test(q) || !/\d/.test(q) || !/[+\-*/%^]/.test(q)) return null;
        try {
            const v = Function(`"use strict"; return (${q.replace(/\^/g, "**")});`)();
            return Number.isFinite(v) ? String(+v.toFixed(10)) : null;
        } catch (e) {
            return null;
        }
    }

    readonly property var apps: DesktopEntries.applications.values
        .filter(e => !e.noDisplay)
        .sort((a, b) => a.name.localeCompare(b.name))

    readonly property var results: {
        const q = query.trim().toLowerCase();
        const out = [];
        if (q === "") {
            const recent = recents.ids.map(id => apps.find(a => a.id === id)).filter(a => a).slice(0, 5);
            for (const a of recent) out.push({ kind: "app", entry: a, section: "Recent" });
            for (const a of apps) if (!recent.includes(a)) out.push({ kind: "app", entry: a, section: "All apps" });
            return out;
        }

        const value = calculate(q);
        if (value !== null) out.push({ kind: "calc", value: value, section: "Calculator" });

        Compositor.windows
            .map(w => ({ w: w, s: score([w.title, w.appId, "workspace " + w.workspace], q) }))
            .filter(x => x.s > 0)
            .sort((a, b) => b.s - a.s)
            .slice(0, 6)
            .forEach(x => out.push({ kind: "window", win: x.w, section: "Windows" }));

        apps.map(a => ({ a: a, s: score([a.name, a.genericName, a.id].concat(a.keywords ?? []), q) }))
            .filter(x => x.s > 0)
            .sort((a, b) => b.s - a.s || a.a.name.localeCompare(b.a.name))
            .forEach(x => out.push({ kind: "app", entry: x.a, section: "Apps" }));
        return out;
    }

    function activate(i): void {
        const r = results[i];
        if (!r) return;
        if (r.kind === "app") {
            r.entry.execute();
            recents.add(r.entry.id);
        } else if (r.kind === "window") {
            Compositor.focusWindow(r.win.address);
        } else if (r.kind === "calc") {
            Quickshell.execDetached(["wl-copy", r.value]);
        }
        ShellState.closeOverlay();
    }

    function move(delta): void {
        if (results.length === 0) return;
        selected = Math.max(0, Math.min(results.length - 1, selected + delta));
        list.positionViewAtIndex(selected, ListView.Contain);
    }

    // ---- Recently launched apps, kept across restarts ----

    QtObject {
        id: recents

        property var ids: []
        readonly property string dir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/hayashi-shell"

        function add(id): void {
            ids = [id].concat(ids.filter(x => x !== id)).slice(0, 12);
            store.setText(JSON.stringify({ recent: ids }));
        }
    }
    Process {
        running: true
        command: ["mkdir", "-p", recents.dir]
    }
    FileView {
        id: store
        path: recents.dir + "/launcher.json"
        printErrors: false
        onLoaded: {
            try {
                recents.ids = JSON.parse(text()).recent ?? [];
            } catch (e) {
                recents.ids = [];
            }
        }
    }

    // ---- Layout ----

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: 24
        anchors.bottomMargin: 24
        anchors.leftMargin: 12
        anchors.rightMargin: 20
        spacing: 14

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 56
            radius: height / 2
            color: Theme.surfaceContainerHighest

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 18
                anchors.rightMargin: 18
                spacing: 12

                Icon {
                    name: "search"
                    color: Theme.fgSurfaceVariant
                }
                TextInput {
                    id: field

                    Layout.fillWidth: true
                    color: Theme.fgSurface
                    selectionColor: Theme.primaryContainer
                    font.family: Tokens.fontFamily
                    font.pixelSize: 18
                    clip: true
                    onTextChanged: {
                        root.query = text;
                        root.selected = 0;
                        list.positionViewAtBeginning();
                    }

                    Keys.onDownPressed: root.move(1)
                    Keys.onUpPressed: root.move(-1)
                    Keys.onTabPressed: root.move(1)
                    Keys.onBacktabPressed: root.move(-1)
                    Keys.onReturnPressed: root.activate(root.selected)
                    Keys.onEnterPressed: root.activate(root.selected)
                    Keys.onEscapePressed: ShellState.closeOverlay()

                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: field.text === ""
                        text: "Search apps, windows, or math"
                        font.pixelSize: 18
                        color: Theme.fgSurfaceVariant
                    }
                }
            }
        }

        Label {
            Layout.fillWidth: true
            Layout.leftMargin: 12
            visible: root.results.length === 0
            text: "Nothing matches “" + root.query + "”."
            color: Theme.fgSurfaceVariant
        }

        ListView {
            id: list

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            model: root.results

            delegate: Item {
                id: row

                required property var modelData
                required property int index
                readonly property bool firstInSection: index === 0 || root.results[index - 1].section !== modelData.section
                readonly property bool isSelected: index === root.selected

                width: ListView.view.width
                height: body.height + (firstInSection ? header.height + (index === 0 ? 0 : 10) : 0)

                Label {
                    id: header

                    visible: row.firstInSection
                    y: row.index === 0 ? 0 : 10
                    x: 12
                    height: 22
                    text: row.modelData.section.toUpperCase()
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.8
                    color: Theme.fgSurfaceVariant
                }

                Rectangle {
                    id: body

                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 58
                    radius: 18
                    color: row.isSelected ? Theme.secondaryContainer : "transparent"

                    readonly property color fg: row.isSelected ? Theme.fgSecondaryContainer : Theme.fgSurface
                    readonly property color fgDim: row.isSelected ? Theme.fgSecondaryContainer : Theme.fgSurfaceVariant
                    // Windows borrow their app's icon when a .desktop file matches.
                    readonly property var entry: row.modelData.kind === "app" ? row.modelData.entry
                        : row.modelData.kind === "window" ? DesktopEntries.heuristicLookup(row.modelData.win.appId)
                        : null

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 14
                        spacing: 14

                        Rectangle {
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 40
                            radius: 13
                            color: row.modelData.kind === "calc" ? Theme.tertiaryContainer : Theme.primaryContainer

                            Image {
                                id: appIcon
                                anchors.centerIn: parent
                                width: 28
                                height: 28
                                sourceSize: Qt.size(56, 56)
                                source: body.entry?.icon ? Quickshell.iconPath(body.entry.icon, true) : ""
                                visible: status === Image.Ready
                            }
                            Icon {
                                anchors.centerIn: parent
                                visible: !appIcon.visible
                                name: row.modelData.kind === "calc" ? "calculate" : row.modelData.kind === "window" ? "select_window" : "apps"
                                color: row.modelData.kind === "calc" ? Theme.fgTertiaryContainer : Theme.fgPrimaryContainer
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Label {
                                Layout.fillWidth: true
                                color: body.fg
                                font.pixelSize: 15
                                font.weight: Font.DemiBold
                                text: row.modelData.kind === "calc" ? row.modelData.value
                                    : row.modelData.kind === "window" ? row.modelData.win.title || row.modelData.win.appId
                                    : row.modelData.entry.name
                            }
                            Label {
                                Layout.fillWidth: true
                                color: body.fgDim
                                font.pixelSize: 12
                                text: row.modelData.kind === "calc" ? "Enter copies the result"
                                    : row.modelData.kind === "window" ? (body.entry?.name ?? row.modelData.win.appId) + " · workspace " + row.modelData.win.workspace
                                    : row.modelData.entry.genericName || row.modelData.entry.comment || ""
                                visible: text !== ""
                            }
                        }

                        Icon {
                            visible: row.isSelected
                            name: "keyboard_return"
                            size: 20
                            color: body.fg
                        }
                    }

                    HoverHandler {
                        onHoveredChanged: if (hovered) root.selected = row.index
                    }
                    TapHandler {
                        onTapped: root.activate(row.index)
                    }
                }
            }
        }
    }
}
