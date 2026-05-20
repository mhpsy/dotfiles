pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Shared caffeine state for the pill and its popup card.
//
// `keepAwake` = !(hypridle running). When hypridle is dead, idle is
// blocked → screen stays on → caffeine "ON".
//
// `inhibitors` is the live `systemd-inhibit` list filtered to idle-blocking
// entries — these are programs that ALSO prevent idle independently of
// our toggle (e.g. browsers playing video, screen-sharing tools).
Singleton {
    id: root
    property bool keepAwake: false
    property var  inhibitors: []     // [{who, what, why}, ...]

    function refresh() { if (!proc.running) proc.running = true }

    Process {
        id: proc
        command: ["bash", Quickshell.env("HOME") + "/.config/quickshell/bar/scripts/caffeine-status.sh"]
        stdout: StdioCollector {
            id: out
            waitForEnd: true
            onStreamFinished: {
                const lines = out.text.split('\n').filter((l) => l.length > 0)
                const inh = []
                for (const line of lines) {
                    if (line.startsWith("__KEEP_AWAKE__ ")) {
                        root.keepAwake = line.endsWith(" true")
                    } else if (line.startsWith("__INHIBITOR__ ")) {
                        const rest = line.substring("__INHIBITOR__ ".length)
                        const parts = rest.split('|')
                        inh.push({
                            who:  parts[0] || "?",
                            what: parts[1] || "",
                            why:  parts[2] || ""
                        })
                    }
                }
                root.inhibitors = inh
            }
        }
    }

    Process {
        id: toggleProc
        command: ["bash", "-c", "~/.config/waybar/caffeine.sh toggle"]
    }
    function toggle() {
        toggleProc.running = false
        toggleProc.running = true
        refreshSoon.restart()
    }
    Timer { id: refreshSoon; interval: 250; onTriggered: root.refresh() }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
    Component.onCompleted: root.refresh()
}
