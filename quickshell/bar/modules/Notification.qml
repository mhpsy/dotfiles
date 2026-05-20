import QtQuick
import Quickshell.Io
import ".."

// swaync indicator — bell icon (or bell-slash for DND), notification count
// when > 0. Left-click toggles the swaync panel; right-click toggles DND.
Rectangle {
    id: root
    property bool dnd: false
    property int  count: 0

    radius:  Theme.radius
    color:   Theme.surfaceContainerHigh
    implicitWidth:  row.implicitWidth + 2 * Theme.pad
    implicitHeight: Theme.pillHeight

    function refresh() { if (!queryProc.running) queryProc.running = true }

    Process {
        id: queryProc
        // "<dnd> <count>" on a single line.
        command: ["bash", "-c",
            "d=$(swaync-client --get-dnd 2>/dev/null); "
            + "c=$(swaync-client --count 2>/dev/null); "
            + "echo \"${d:-false} ${c:-0}\""]
        stdout: StdioCollector {
            id: out
            waitForEnd: true
            onStreamFinished: {
                const parts = out.text.trim().split(/\s+/)
                root.dnd = parts[0] === "true"
                root.count = parseInt(parts[1]) || 0
            }
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
    Component.onCompleted: root.refresh()

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 4
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.dnd ? "" : ""        // bell-slash / bell
            font.family:    Theme.glyphFont
            font.styleName: Theme.glyphStyle
            font.pixelSize: Theme.glyphSize
            color:          root.dnd ? Theme.error : Theme.fgSurfaceVariant
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible:        root.count > 0
            text:           root.count.toString()
            font.family:    Theme.uiFont
            font.pixelSize: Theme.glyphSize
            color:          Theme.fgSurface
        }
    }

    Process { id: actionProc }

    MouseArea {
        anchors.fill: parent
        cursorShape:  Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (e) => {
            actionProc.command = ["bash", "-c",
                e.button === Qt.RightButton
                    ? "swaync-client -d"   // toggle DND
                    : "swaync-client -t"]  // toggle panel
            actionProc.running = true
            root.refresh()
        }
    }
}
