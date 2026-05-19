import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    property bool ok: false
    property string city: "--"
    property var current: ({})
    property var hourly: []
    property var daily: []
    property string lastError: ""

    function refresh() { proc.running = true }

    Process {
        id: proc
        command: ["bash", "-c",
            "~/.config/waybar/weather.sh >/dev/null 2>&1; ~/.config/waybar/weather-eww.sh"]
        stdout: StdioCollector {
            id: out
            waitForEnd: true
            onStreamFinished: {
                try {
                    var j = JSON.parse(out.text)
                    root.ok = j.ok === true
                    root.city = j.city || "--"
                    root.current = j.current || ({})
                    root.hourly = j.hourly || []
                    root.daily = j.daily || []
                    root.lastError = ""
                } catch (e) {
                    root.ok = false
                    root.lastError = "" + e
                }
            }
        }
    }

    Timer {
        interval: 900000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
