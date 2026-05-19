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
                    // `current` (the active word object) DOES change on pick/rotate →
                    // reassign so the card hero + highlight follow.
                    if (JSON.stringify(nc) !== JSON.stringify(root.current)) root.current = nc
                    // `today` is the day's word LIST. It changes only on daily
                    // rotation, NOT on pick (a pick just moves the per-entry
                    // `current` flag). Compare IGNORING that flag so the array
                    // reference stays stable across picks → Repeater does NOT
                    // rebuild → the entrance cascade plays once on open, not on
                    // every word-click. Which row is "current" is derived in
                    // WordCard from `current.word`, not from this stale flag.
                    var ntId = JSON.stringify(nt.map(function (e) { return [e.idx, e.word, e.meaning] }))
                    var otId = JSON.stringify((root.today || []).map(function (e) { return [e.idx, e.word, e.meaning] }))
                    if (ntId !== otId) root.today = nt
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
