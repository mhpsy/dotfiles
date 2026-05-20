pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Live `hyprctl clients` snapshot. Each entry has at minimum:
//   { class, title, pid, workspace: { id, name }, address, ... }
//
// Refresh strategy: subscribe to relevant Hyprland events (openwindow,
// closewindow, movewindow, activewindow, ...) for instant updates; keep a
// 5s polling timer as belt-and-braces in case rawEvent isn't wired up.
Singleton {
    id: root
    property var clients: []

    function refresh() { if (!proc.running) proc.running = true }

    function clientsInWorkspace(name) {
        const out = []
        for (let i = 0; i < root.clients.length; i++) {
            const c = root.clients[i]
            if (c && c.workspace && c.workspace.name === name) out.push(c)
        }
        return out
    }

    Process {
        id: proc
        command: ["bash", "-c", "hyprctl clients -j"]
        stdout: StdioCollector {
            id: out
            waitForEnd: true
            onStreamFinished: {
                try {
                    root.clients = JSON.parse(out.text) || []
                } catch (_) {
                    root.clients = []
                }
            }
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (!event) return
            const n = "" + event.name
            if (n.indexOf("window")        >= 0
             || n.indexOf("movewindow")    >= 0
             || n.indexOf("activewindow")  >= 0
             || n.indexOf("closewindow")   >= 0
             || n.indexOf("openwindow")    >= 0
             || n.indexOf("changefloating") >= 0) {
                root.refresh()
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
    Component.onCompleted: root.refresh()
}
