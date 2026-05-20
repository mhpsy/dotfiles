pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Shared CPU / RAM telemetry. Replaces the inline polling that lived inside
// modules/SystemMonitor.qml — now both the pill and the popup card read
// from this singleton (DRY + a single set of polling timers).
//
// Top-process lists are sampled less often than the percentage because
// `ps aux --sort` is heavier than `head -1 /proc/stat`.
Singleton {
    id: root
    property int cpuPct: 0
    property int ramPct: 0

    // [{cmd, pct}, ...] — top by CPU then top by RAM, length up to 5 each.
    property var topCpu: []
    property var topRam: []

    property real _prevTotal: 0
    property real _prevIdle:  0

    function refresh() {
        if (!cpuProc.running) cpuProc.running = true
        if (!ramProc.running) ramProc.running = true
    }
    function refreshTop() {
        if (!topCpuProc.running) topCpuProc.running = true
        if (!topRamProc.running) topRamProc.running = true
    }

    Process {
        id: cpuProc
        command: ["bash", "-c", "head -1 /proc/stat"]
        stdout: StdioCollector {
            id: cpuOut
            waitForEnd: true
            onStreamFinished: {
                const f = cpuOut.text.trim().split(/\s+/)
                if (f.length < 8) return
                const user    = parseInt(f[1]) || 0
                const nice    = parseInt(f[2]) || 0
                const sys     = parseInt(f[3]) || 0
                const idle    = parseInt(f[4]) || 0
                const iowait  = parseInt(f[5]) || 0
                const irq     = parseInt(f[6]) || 0
                const softirq = parseInt(f[7]) || 0
                const total     = user + nice + sys + idle + iowait + irq + softirq
                const totalIdle = idle + iowait
                if (root._prevTotal > 0) {
                    const dt = total - root._prevTotal
                    const di = totalIdle - root._prevIdle
                    if (dt > 0) root.cpuPct = Math.max(0, Math.min(100, Math.round(100 * (dt - di) / dt)))
                }
                root._prevTotal = total
                root._prevIdle  = totalIdle
            }
        }
    }
    Process {
        id: ramProc
        command: ["bash", "-c", "free | awk '/^Mem:/ {printf \"%d\", $3*100/$2}'"]
        stdout: StdioCollector {
            id: ramOut
            waitForEnd: true
            onStreamFinished: {
                const v = parseInt(ramOut.text.trim())
                if (!isNaN(v)) root.ramPct = v
            }
        }
    }

    Process {
        id: topCpuProc
        command: ["bash", "-c",
            "ps -eo pcpu,comm --no-headers --sort=-pcpu 2>/dev/null | head -5"]
        stdout: StdioCollector {
            id: topCpuOut
            waitForEnd: true
            onStreamFinished: {
                const out = []
                for (const line of topCpuOut.text.split('\n')) {
                    const m = line.trim().match(/^(\d+(?:\.\d+)?)\s+(.+)$/)
                    if (m) out.push({ pct: parseFloat(m[1]), cmd: m[2] })
                }
                root.topCpu = out
            }
        }
    }
    Process {
        id: topRamProc
        command: ["bash", "-c",
            "ps -eo pmem,comm --no-headers --sort=-pmem 2>/dev/null | head -5"]
        stdout: StdioCollector {
            id: topRamOut
            waitForEnd: true
            onStreamFinished: {
                const out = []
                for (const line of topRamOut.text.split('\n')) {
                    const m = line.trim().match(/^(\d+(?:\.\d+)?)\s+(.+)$/)
                    if (m) out.push({ pct: parseFloat(m[1]), cmd: m[2] })
                }
                root.topRam = out
            }
        }
    }

    Timer {
        interval: 2500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
    Timer {
        // Top lists update less often — `ps aux` is more expensive
        interval: 4000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshTop()
    }
    Component.onCompleted: { root.refresh(); root.refreshTop() }
}
