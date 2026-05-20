import QtQuick
import Quickshell
import ".."

// Clock pill with seconds (HH:mm:ss).
//
// SystemClock.Seconds ticks at 1Hz — necessary for the seconds digit. The
// label's implicit width stays stable (seconds are always 2 digits 00..59) so
// the pill doesn't keep nudging neighboring modules.
Rectangle {
    id: root
    color:  Theme.surfaceContainerHigh
    radius: Theme.radius
    implicitWidth:  label.implicitWidth + 2 * Theme.pad
    implicitHeight: Theme.pillHeight

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    Text {
        id: label
        anchors.centerIn: parent
        text:        Qt.formatDateTime(clock.date, "HH:mm:ss")
        color:       Theme.fgSurface
        // monospace so seconds tick without nudging the pill width.
        font.family: Theme.monoFont
        font.pixelSize: Theme.clockSize
    }
}
