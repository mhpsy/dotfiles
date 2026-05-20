pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Shared word-of-the-day provider. Mirrors word-island/WordData.qml — the
// `active` flag is driven externally (shell.qml binds it to PopupState's
// word-popup open state) to gate the 1.5s refresh Timer.
Singleton {
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

    // Fast-refresh Timer — only runs while the popup card is visible so the
    // pick/rotate UI feels live. The bar pill outside of that uses the slow
    // refresh below.
    Timer {
        interval: 1500
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    // Slow background refresh — keeps the bar pill text current (rotation
    // happens at most every few minutes via word-stream.sh). 60s is plenty.
    Timer {
        interval: 60 * 1000
        running: !root.active
        repeat: true
        onTriggered: root.refresh()
    }

    // Initial fetch on startup so the bar pill has text before the user ever
    // hovers — without this the pill stays hidden (visible: !!cur.word).
    Component.onCompleted: root.refresh()
}
