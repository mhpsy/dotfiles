pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Shared backlight state — used by both modules/Brightness.qml (pill) and
// BrightnessCard.qml (slider popup). Delegates the actual hardware access
// to ~/.config/waybar/brightness.sh, which transparently prefers
// brightnessctl (laptop) and falls back to ddcutil (external monitor).
Singleton {
    id: root
    property int percent: 50

    function refresh()      { runScript("get") }
    function setPercent(p)  { runScript("set " + Math.max(1, Math.min(100, Math.round(p)))) }
    function up()           { runScript("up") }
    function down()         { runScript("down") }

    function runScript(verb) {
        proc.command = ["bash", "-c", "~/.config/waybar/brightness.sh " + verb]
        proc.running = true
    }

    Process {
        id: proc
        stdout: StdioCollector {
            id: out
            waitForEnd: true
            onStreamFinished: {
                try {
                    const j = JSON.parse(out.text)
                    const v = parseInt(j.percentage)
                    if (!isNaN(v)) root.percent = v
                } catch (_) {}
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
    Component.onCompleted: root.refresh()
}
