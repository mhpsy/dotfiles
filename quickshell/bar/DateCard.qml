import QtQuick
import QtQuick.Layouts
import Quickshell
import "."

// 3-month calendar popup: previous, current, next.
// Today's cell is highlighted in current month.
Item {
    id: card
    implicitWidth:  3 * monthW + 2 * Theme.gap + 28   // three months + gaps + outer padding
    implicitHeight: row.implicitHeight + 24

    readonly property int monthW: 130       // single-month column width
    readonly property int cellSize: 18      // each day cell
    readonly property int dayHeaderSize: 14 // M T W ... row height

    // SystemClock.Hours is the coarsest precision Quickshell exposes — plenty
    // for a calendar (the binding still re-fires the instant we cross midnight).
    SystemClock {
        id: clock
        precision: SystemClock.Hours
    }

    // Build a 6-row × 7-col grid (always 42 cells) for the given year/month.
    // Empty cells (before month start / after month end) hold null.
    function monthCells(year, month) {
        const first   = new Date(year, month, 1)
        // Monday-start (waybar default). first.getDay(): 0=Sun..6=Sat
        const offset  = (first.getDay() + 6) % 7
        const lastDay = new Date(year, month + 1, 0).getDate()
        const cells   = []
        for (let i = 0; i < offset; i++) cells.push(null)
        for (let d = 1; d <= lastDay; d++) cells.push(d)
        while (cells.length < 42) cells.push(null)
        return cells
    }
    function monthName(year, month) {
        return year + " · " + (month + 1) + " 月"
    }

    readonly property var today: clock.date
    readonly property int todayY: today.getFullYear()
    readonly property int todayM: today.getMonth()
    readonly property int todayD: today.getDate()

    function offsetMonth(delta) {
        const d = new Date(todayY, todayM + delta, 1)
        return { y: d.getFullYear(), m: d.getMonth() }
    }

    RowLayout {
        id: row
        anchors {
            left:    parent.left
            right:   parent.right
            top:     parent.top
            margins: 14
        }
        spacing: Theme.gap

        Repeater {
            model: [-1, 0, 1]
            delegate: ColumnLayout {
                required property int modelData
                readonly property var mInfo: card.offsetMonth(modelData)
                readonly property bool isCurrent: modelData === 0
                Layout.preferredWidth: card.monthW
                spacing: 4

                // ---- month title ----
                Text {
                    Layout.fillWidth: true
                    text:        card.monthName(mInfo.y, mInfo.m)
                    color:       isCurrent ? Theme.primary : Theme.fgSurfaceVariant
                    font.family: Theme.uiFont
                    font.pixelSize: 12
                    font.bold:   isCurrent
                    horizontalAlignment: Text.AlignHCenter
                }

                // ---- day-of-week header (Mon-Sun) ----
                GridLayout {
                    Layout.fillWidth: true
                    columns: 7
                    rowSpacing: 0
                    columnSpacing: 0
                    Repeater {
                        model: ["一", "二", "三", "四", "五", "六", "日"]
                        delegate: Item {
                            required property int index
                            required property string modelData
                            Layout.fillWidth:  true
                            Layout.preferredHeight: card.dayHeaderSize
                            Text {
                                anchors.centerIn: parent
                                text:        modelData
                                // Sat/Sun in slight accent
                                color:       index >= 5
                                                 ? Theme.tertiary
                                                 : Theme.fgSurfaceVariant
                                font.family: Theme.uiFont
                                font.pixelSize: 9
                                font.bold:   true
                            }
                        }
                    }
                }

                // ---- day cells ----
                GridLayout {
                    Layout.fillWidth: true
                    columns: 7
                    rowSpacing: 1
                    columnSpacing: 1
                    Repeater {
                        model: card.monthCells(mInfo.y, mInfo.m)
                        delegate: Item {
                            required property int index
                            required property var modelData    // day number or null
                            readonly property bool isToday:
                                isCurrent && modelData === card.todayD
                            readonly property bool isWeekend:
                                modelData !== null && (index % 7) >= 5

                            Layout.fillWidth: true
                            Layout.preferredHeight: card.cellSize

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 1
                                visible: isToday
                                radius:  width / 2
                                color:   Theme.primary
                            }

                            Text {
                                anchors.centerIn: parent
                                text:        modelData !== null ? modelData : ""
                                color:       isToday
                                                 ? Theme.fgPrimaryContainer
                                                 : isWeekend
                                                     ? Theme.tertiary
                                                     : Theme.fgSurface
                                font.family: Theme.monoFont
                                font.pixelSize: 10
                                font.bold:   isToday
                            }
                        }
                    }
                }
            }
        }
    }
}
