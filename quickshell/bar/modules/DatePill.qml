import QtQuick
import Quickshell
import ".."

// Date pill (sibling of Clock). Splitting date from time keeps each on a
// dedicated SystemClock precision: Minutes for HH:mm, Day for the date — no
// per-second wakeups in either.
Rectangle {
    id: root
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

    // Chinese weekday in addition to MM-dd. We compute it in JS rather than
    // relying on Qt.locale("zh_CN") because the QML formatter doesn't always
    // produce the short "周X" form we want.
    readonly property var _wd: ["日", "一", "二", "三", "四", "五", "六"]

    Text {
        id: label
        anchors.centerIn: parent
        text:        Qt.formatDate(clock.date, "MM-dd") + "  周" + root._wd[clock.date.getDay()]
        color:       Theme.fgSurfaceVariant
        font.family: Theme.monoFont
        font.pixelSize: Theme.clockSize
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: PopupState.openDate()
        onExited:  PopupState.closeDate()
    }

    function reportAnchor() { PopupState.dateAnchorX = mapToItem(null, width / 2, 0).x }
    onXChanged:            reportAnchor()
    onWidthChanged:        reportAnchor()
    Component.onCompleted: reportAnchor()
}
