pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Shared pending-updates list. Used by modules/Updates.qml (pill count) and
// UpdatesCard.qml (popup with full list).
//
// Two separate processes — checkupdates for the official repos (pacman)
// and `yay -Qua` for AUR — so each can land independently. Both are
// expected to be slow (network access), so we cache the lists and only
// re-poll every 10 minutes.
Singleton {
    id: root
    property var pacmanList: []   // ["pkg current -> new", ...]
    property var aurList:    []
    readonly property int pacmanCount: pacmanList.length
    readonly property int aurCount:    aurList.length
    readonly property int totalCount:  pacmanCount + aurCount

    function refresh() {
        if (!pacmanProc.running) pacmanProc.running = true
        if (!aurProc.running)    aurProc.running    = true
    }

    Process {
        id: pacmanProc
        command: ["bash", "-c", "checkupdates 2>/dev/null"]
        stdout: StdioCollector {
            id: pOut
            waitForEnd: true
            onStreamFinished: {
                const t = pOut.text.trim()
                root.pacmanList = t ? t.split('\n').filter((l) => l.length > 0) : []
            }
        }
    }
    Process {
        id: aurProc
        command: ["bash", "-c", "yay -Qua 2>/dev/null"]
        stdout: StdioCollector {
            id: aOut
            waitForEnd: true
            onStreamFinished: {
                const t = aOut.text.trim()
                root.aurList = t ? t.split('\n').filter((l) => l.length > 0) : []
            }
        }
    }

    Timer {
        interval: 10 * 60 * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
    Component.onCompleted: root.refresh()
}
