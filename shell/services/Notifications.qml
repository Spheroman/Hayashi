pragma Singleton

import Quickshell
import Quickshell.Services.Notifications
import QtQuick

// The notification daemon (org.freedesktop.Notifications). Keeps every
// notification until it's dismissed, and a short list of the ones currently
// showing as popups.
Singleton {
    id: root

    property bool dnd: false

    // Newest first. Each entry is { n: Notification, time: Date }.
    property var list: []
    property var popups: []

    readonly property int count: list.length

    function remove(n): void {
        list = list.filter(e => e.n !== n);
        popups = popups.filter(e => e.n !== n);
    }

    function hidePopup(n): void {
        popups = popups.filter(e => e.n !== n);
    }

    // Dismissing tells the sender; the `closed` signal then removes it here.
    function dismiss(n): void {
        n.dismiss();
    }

    function clearAll(): void {
        for (const e of list.slice()) e.n.dismiss();
    }

    // Runs the notification's default action if it has one, otherwise just
    // dismisses it.
    function activate(n): void {
        let action = null;
        for (let i = 0; i < n.actions.length; i++) {
            if (n.actions[i].identifier === "default") action = n.actions[i];
        }
        if (action) action.invoke();
        else n.dismiss();
    }

    NotificationServer {
        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: true
        actionsSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: n => {
            n.tracked = true;
            const entry = { n: n, time: new Date() };
            root.list = [entry].concat(root.list);

            const critical = n.urgency === NotificationUrgency.Critical;
            if (critical || (!root.dnd && !ShellState.panelsOpen))
                root.popups = [entry].concat(root.popups).slice(0, 4);

            n.closed.connect(() => root.remove(n));
        }
    }
}
