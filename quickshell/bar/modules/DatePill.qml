import QtQuick
import Quickshell
import ".."

// Date pill (sibling of Clock). Splitting date from time keeps each on a
// dedicated SystemClock precision: Minutes for HH:mm, Day for the date — no
// per-second wakeups in either.
Rectangle {
    color:  Theme.surfaceContainerHigh
    radius: Theme.radius
    implicitWidth:  label.implicitWidth + 2 * Theme.pad
    implicitHeight: Theme.pillHeight

    // SystemClock.Hours is the coarsest precision exposed (no Day enum); a
    // 60-minute tick is plenty for a date label — the binding still fires the
    // moment we cross midnight.
    SystemClock {
        id: clock
        precision: SystemClock.Hours
    }

    Text {
        id: label
        anchors.centerIn: parent
        text:        Qt.formatDate(clock.date, "MM-dd ddd")
        color:       Theme.fgSurfaceVariant
        font.family: Theme.monoFont
        font.pixelSize: Theme.clockSize
    }
}
