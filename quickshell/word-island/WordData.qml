import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    property bool active: false
    property bool ok: false
    property var current: ({})
    property var today: []
    property string lastError: ""

    function refresh() { if (!proc.running) proc.running = true }

    Process {
        id: proc
        command: ["bash", "-c", "~/.config/waybar/word-popup.sh"]
        stdout: StdioCollector {
            id: out
            // waitForEnd: true is load-bearing: onStreamFinished then fires exactly
            // once per run with the COMPLETE stdout. Do not remove.
            waitForEnd: true
            onStreamFinished: {
                try {
                    var j = JSON.parse(out.text)
                    var nc = j.current || ({})
                    var nt = j.today || []
                    // word-popup.sh emits identical JSON within a ~600s rotation
                    // window; only reassign when content actually changed so the
                    // Repeater model reference stays stable (no per-poll delegate
                    // rebuild → clicks/entrance animations survive across polls).
                    if (JSON.stringify(nc) !== JSON.stringify(root.current)) root.current = nc
                    if (JSON.stringify(nt) !== JSON.stringify(root.today)) root.today = nt
                    root.ok = !!(root.current && root.current.word)
                    root.lastError = ""
                } catch (e) {
                    root.ok = false
                    root.lastError = "" + e
                }
            }
        }
    }

    Timer {
        interval: 1500
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
