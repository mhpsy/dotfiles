import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "."

// Clock popup — bigger local time + world clocks + detail row + uptime.
//
//   Local       HH:mm:ss + full date with weekday
//   World       California / Toronto (Canada) / Tokyo / Seoul, HH:mm
//   Detail      ISO week · day of year · UNIX timestamp
//   Uptime      "已开机 Xd Yh Zm" (polled every minute)
Item {
    id: card
    implicitWidth:  340
    implicitHeight: col.implicitHeight + 24

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    // Uptime — Process polls /proc/uptime via a tiny script. Minute cadence
    // is plenty (the popup card only ever displays days/hours/min granularity).
    property int uptimeSec: 0
    Process {
        id: uptimeProc
        command: ["bash", Quickshell.env("HOME") + "/.config/quickshell/bar/scripts/uptime.sh"]
        stdout: StdioCollector {
            id: uptimeOut
            waitForEnd: true
            onStreamFinished: {
                const v = parseInt(uptimeOut.text.trim())
                if (!isNaN(v)) card.uptimeSec = v
            }
        }
    }
    Timer { interval: 60 * 1000; running: true; repeat: true; triggeredOnStart: true
            onTriggered: if (!uptimeProc.running) uptimeProc.running = true }

    // World clocks — shell out via TZ=… because Qt 6.11's QML JS engine
    // silently ignores the timeZone option on Date.toLocaleString.
    property var worldTimes: ({ california: "--:--", toronto: "--:--", tokyo: "--:--", seoul: "--:--" })
    Process {
        id: worldProc
        command: ["bash", Quickshell.env("HOME") + "/.config/quickshell/bar/scripts/world-times.sh"]
        stdout: StdioCollector {
            id: worldOut
            waitForEnd: true
            onStreamFinished: {
                const m = ({})
                for (const line of worldOut.text.split('\n')) {
                    const eq = line.indexOf('=')
                    if (eq > 0) m[line.substring(0, eq)] = line.substring(eq + 1)
                }
                card.worldTimes = m
            }
        }
    }
    Timer { interval: 30 * 1000; running: true; repeat: true; triggeredOnStart: true
            onTriggered: if (!worldProc.running) worldProc.running = true }

    function fmtZone(key) { return card.worldTimes[key] || "--:--" }
    function fmtUptime() {
        const s = card.uptimeSec
        const d = Math.floor(s / 86400)
        const h = Math.floor((s % 86400) / 3600)
        const m = Math.floor((s % 3600) / 60)
        if (d > 0) return d + " 天 " + h + " 小时 " + m + " 分"
        if (h > 0) return h + " 小时 " + m + " 分"
        return m + " 分钟"
    }
    function isoWeek() {
        // ISO 8601 week number computation (week starts Monday)
        const d = new Date(clock.date)
        d.setHours(0, 0, 0, 0)
        // Thursday of this week determines the year-of-week
        d.setDate(d.getDate() + 3 - ((d.getDay() + 6) % 7))
        const week1 = new Date(d.getFullYear(), 0, 4)
        return 1 + Math.round(((d.getTime() - week1.getTime()) / 86400000 - 3 + ((week1.getDay() + 6) % 7)) / 7)
    }
    function dayOfYear() {
        const start = new Date(clock.date.getFullYear(), 0, 0)
        const diff = clock.date - start
        return Math.floor(diff / 86400000)
    }

    ColumnLayout {
        id: col
        anchors {
            left:    parent.left
            right:   parent.right
            top:     parent.top
            margins: 14
        }
        spacing: 10

        // ---- big local time ----
        ColumnLayout {
            Layout.fillWidth: true
            spacing: -2
            Text {
                text:        Qt.formatDateTime(clock.date, "HH:mm:ss")
                color:       Theme.fgSurface
                font.family: Theme.monoFont
                font.pixelSize: 36
                font.bold:   true
            }
            Text {
                text:        Qt.formatDate(clock.date, "yyyy年 M月 d日 dddd")
                color:       Theme.fgSurfaceVariant
                font.family: Theme.uiFont
                font.pixelSize: 12
            }
        }

        Rectangle {
            Layout.fillWidth: true; height: 1
            color: Theme.outline; opacity: 0.2
        }

        // ---- world clocks ----
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3
            Text {
                text: "世界时间"
                color: Theme.fgSurfaceVariant
                font.family: Theme.uiFont
                font.pixelSize: 10
                font.letterSpacing: 1
            }
            Repeater {
                model: [
                    { city: "加州",   key: "california", tz: "America/Los_Angeles" },
                    { city: "多伦多", key: "toronto",    tz: "America/Toronto"     },
                    { city: "东京",   key: "tokyo",      tz: "Asia/Tokyo"          },
                    { city: "首尔",   key: "seoul",      tz: "Asia/Seoul"          }
                ]
                delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 6
                    Text {
                        Layout.fillWidth: true
                        text:        modelData.city
                        color:       Theme.fgSurface
                        font.family: Theme.uiFont
                        font.pixelSize: 12
                    }
                    Text {
                        text:        modelData.tz.replace(/.*\//, "").replace(/_/g, ' ')
                        color:       Theme.fgSurfaceVariant
                        font.family: Theme.uiFont
                        font.pixelSize: 10
                    }
                    Text {
                        text:        card.fmtZone(modelData.key)
                        color:       Theme.fgSurface
                        font.family: Theme.monoFont
                        font.pixelSize: 13
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true; height: 1
            color: Theme.outline; opacity: 0.2
        }

        // ---- detail + uptime ----
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text {
                text:        "第 " + card.isoWeek() + " 周  ·  一年第 " + card.dayOfYear() + " 天"
                color:       Theme.fgSurfaceVariant
                font.family: Theme.uiFont
                font.pixelSize: 11
            }
            Text {
                text:        "UNIX  " + Math.floor(clock.date.getTime() / 1000)
                color:       Theme.fgSurfaceVariant
                font.family: Theme.monoFont
                font.pixelSize: 10
            }
            Text {
                text:        "已开机  " + card.fmtUptime()
                color:       Theme.fgSurfaceVariant
                font.family: Theme.uiFont
                font.pixelSize: 11
            }
        }
    }
}
