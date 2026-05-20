pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Tracks which Hyprland special workspaces are currently open on any monitor.
//
// Implementation mirrors waybar/special-workspace.sh: poll `hyprctl monitors`
// for the `specialWorkspace.name` field on each monitor and union the names.
// This works regardless of what Quickshell's HyprlandMonitor binding exposes
// (which on this 0.3.0 build does NOT surface specialWorkspace as a QML
// property — we tried).
//
// Refresh triggers:
//   * Hyprland.rawEvent — when available, gives near-instant updates on
//     activespecial / activespecialv2 events (the same events waybar tails on
//     socket2).
//   * Polling Timer — 1.5s safety net if rawEvent isn't wired up on this
//     build, and for cases where the first refresh races startup.
//   * SpecialButton calls refresh() right after its dispatch to short-circuit
//     the event roundtrip for snappier UI.
Singleton {
    id: root

    // Map of "special:<name>" -> true; absence == not open.
    property var openMap: ({})

    function isActive(shortName) { return root.openMap["special:" + shortName] === true }
    function refresh()           { if (!proc.running) proc.running = true             }

    Process {
        id: proc
        command: ["bash", "-c",
            "hyprctl monitors -j | jq -c '[.[] | .specialWorkspace.name | select(. != \"\")]'"]
        stdout: StdioCollector {
            id: out
            waitForEnd: true
            onStreamFinished: {
                try {
                    const arr = JSON.parse(out.text)
                    const next = {}
                    for (let i = 0; i < arr.length; i++) {
                        if (arr[i]) next[arr[i]] = true
                    }
                    root.openMap = next
                } catch (_) {}
            }
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (!event) return
            const n = ("" + event.name)
            if (n === "activespecial" || n === "activespecialv2") root.refresh()
        }
    }

    Timer {
        interval: 1500
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: root.refresh()
}
