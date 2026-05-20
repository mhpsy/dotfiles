pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Shared network state.
//
//   ifaceType   "wifi" / "ethernet" / "" (disconnected)
//   ifname      e.g. "wlan0", "enp0s31f6"
//   ipAddr      primary IPv4
//   signalPct   wifi only, 0..100
//   rxRate      download rate (bytes/sec)
//   txRate      upload rate (bytes/sec)
Singleton {
    id: root
    property string ifaceType: ""
    property string ifname:    ""
    property string ipAddr:    ""
    property int    signalPct: 0
    property real   rxRate:    0
    property real   txRate:    0

    readonly property bool connected: ifaceType.length > 0

    // ---- status (slow) ----
    function refresh() { if (!statusProc.running) statusProc.running = true }

    Process {
        id: statusProc
        command: ["bash", Quickshell.env("HOME") + "/.config/quickshell/bar/scripts/network-status.sh"]
        stdout: StdioCollector {
            id: statusOut
            waitForEnd: true
            onStreamFinished: {
                const parts = statusOut.text.trim().split('|')
                root.ifaceType = parts[0] || ""
                root.ifname    = parts[1] || ""
                root.ipAddr    = parts[2] || ""
                root.signalPct = parseInt(parts[3]) || 0
            }
        }
    }

    // ---- bandwidth (fast) ----
    property real _prevRx: 0
    property real _prevTx: 0
    property real _prevSampleMs: 0

    Process {
        id: rateProc
        command: ["bash", Quickshell.env("HOME") + "/.config/quickshell/bar/scripts/network-rate.sh"]
        stdout: StdioCollector {
            id: rateOut
            waitForEnd: true
            onStreamFinished: {
                const parts = rateOut.text.trim().split(/\s+/)
                const rx = parseFloat(parts[0]) || 0
                const tx = parseFloat(parts[1]) || 0
                const now = Date.now()
                if (root._prevSampleMs > 0) {
                    const dt = (now - root._prevSampleMs) / 1000
                    if (dt > 0) {
                        root.rxRate = Math.max(0, (rx - root._prevRx) / dt)
                        root.txRate = Math.max(0, (tx - root._prevTx) / dt)
                    }
                }
                root._prevRx = rx
                root._prevTx = tx
                root._prevSampleMs = now
            }
        }
    }

    Timer {
        interval: 1500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!rateProc.running) rateProc.running = true
        }
    }
    Timer {
        // slower full-status refresh — IP / ifname rarely change
        interval: 10 * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
    Component.onCompleted: root.refresh()

    // ---- helper: human-readable bytes/sec ----
    function fmtBytes(b) {
        if (b < 1024)        return Math.round(b) + " B/s"
        if (b < 1024 * 1024) return (b / 1024).toFixed(1) + " KB/s"
        return (b / 1024 / 1024).toFixed(2) + " MB/s"
    }
}
