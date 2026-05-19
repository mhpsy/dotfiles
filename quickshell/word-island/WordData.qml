import QtQuick
import Quickshell
import Quickshell.Io

Item {
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
            waitForEnd: true
            onStreamFinished: {
                try {
                    var j = JSON.parse(out.text)
                    root.current = j.current || ({})
                    root.today = j.today || []
                    root.ok = !!(root.current && root.current.word)
                    root.lastError = ""
                } catch (e) {
                    root.ok = false
                    root.lastError = "" + e
                }
            }
        }
    }

    Timer {
        interval: 1500
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
