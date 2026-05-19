import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "."

ShellRoot {
    WlrLayershell {
        id: win
        anchors { top: true; left: true }
        margins.left: 120          // approx x: transient dropdown near the quotes module; tunable
        margins.top: 40            // bar height ~40 → card hangs just below the bar
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        layer: WlrLayer.Overlay
        keyboardFocus: WlrKeyboardFocus.None
        namespace: "qs-word-island"

        implicitWidth: card.implicitWidth
        implicitHeight: card.implicitHeight

        mask: Region { item: win.open ? card : null }

        WordData { id: words; active: win.open }

        property bool open: false
        function syncOpen() {
            var t = stateFile.text()
            win.open = t ? t.trim() === "1" : false
        }
        FileView {
            id: stateFile
            path: "/tmp/qs-word-open"
            watchChanges: true
            printErrors: false
            onFileChanged: reload()
            onTextChanged: win.syncOpen()
            onLoaded: win.syncOpen()
        }
        Timer { interval: 400; running: true; repeat: true; onTriggered: stateFile.reload() }

        WordCard {
            id: card
            words: words
            visible: opacity > 0.01
            opacity: win.open ? 1 : 0
            scale: win.open ? 1 : 0.96
            transformOrigin: Item.Top
            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on scale   { SpringAnimation { spring: 4.0; damping: 0.5; epsilon: 0.01 } }
        }
    }
}
