import QtQuick
import Quickshell.Io
import ".."

// Reboot-pending indicator — uses ~/.config/waybar/reboot.sh which checks
// whether the running kernel's /usr/lib/modules dir still exists (canonical
// "needs reboot" signal on Arch). Hidden when no reboot is pending.
//
// Click triggers `systemctl reboot` (after pressing enter to confirm? — no,
// direct). Right-click cancels (no-op for safety).
Rectangle {
    id: root
    property bool pending: false

    visible: pending
    radius:  Theme.radius
    color:   Theme.surfaceContainerHigh
    implicitWidth:  visible ? icon.implicitWidth + 2 * Theme.pad : 0
    implicitHeight: Theme.barHeight - 8

    function refresh() { if (!proc.running) proc.running = true }

    Process {
        id: proc
        command: ["bash", "-c", "~/.config/waybar/reboot.sh"]
        stdout: StdioCollector {
            id: out
            waitForEnd: true
            onStreamFinished: {
                try {
                    const j = JSON.parse(out.text)
                    root.pending = (j.text || "").length > 0
                } catch (_) {}
            }
        }
    }

    Timer {
        interval: 60 * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
    Component.onCompleted: root.refresh()

    Text {
        id: icon
        anchors.centerIn: parent
        text: ""   // fa-rotate
        font.family:    Theme.glyphFont
        font.styleName: Theme.glyphStyle
        font.pixelSize: 12
        color:          Theme.error
    }

    Process { id: rebootProc; command: ["bash", "-c", "systemctl reboot"] }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: rebootProc.running = true
    }
}
