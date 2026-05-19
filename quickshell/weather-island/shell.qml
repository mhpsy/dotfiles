import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "."

ShellRoot {
    WlrLayershell {
        id: win
        anchors { top: true; left: true }
        margins.left: 120          // approx x: card is a transient dropdown near the weather module; tunable
        margins.top: 40            // bar height ~40 → card hangs just below the bar
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        layer: WlrLayer.Overlay
        keyboardFocus: WlrKeyboardFocus.None
        namespace: "qs-weather-island"

        // FIXED Wayland surface = card bbox. NEVER animate / NEVER add a Behavior here.
        // Only changes on weather-data refresh (card.implicitHeight, ~15min), never on
        // open/close → zero per-frame surface reconfigure → jitter structurally impossible.
        implicitWidth: card.implicitWidth
        implicitHeight: card.implicitHeight

        // Input region: open → card rect (interactive); closed → null Region → the big
        // transparent surface is 100% click-through (zero dead zone, zero footprint).
        mask: Region { item: win.open ? card : null }

        WeatherData { id: wx }

        // Open/closed driven by /tmp/qs-weather-open (waybar on-click flips it via
        // qs-weather-toggle.sh). MACHINE-VERIFIED FileView behavior on this build
        // (Quickshell 0.3.0): reads are ASYNC. At onFileChanged the cached text() is
        // still the OLD value; reload() kicks an async re-read and the fresh content
        // arrives via onTextChanged / onLoaded. So: reload() on fileChanged, and read
        // the value from onTextChanged/onLoaded (the plan's onFileChanged+text() guess
        // would latch the stale value — confirmed via debug logging).
        property bool open: false
        function syncOpen() {
            var t = stateFile.text()
            win.open = t ? t.trim() === "1" : false
        }
        FileView {
            id: stateFile
            path: "/tmp/qs-weather-open"
            watchChanges: true
            onFileChanged: reload()      // async re-read; value lands in onTextChanged
            onTextChanged: win.syncOpen()
            onLoaded: win.syncOpen()
        }
        // Robustness net (MACHINE-VERIFIED): on this build, if the watched file does
        // NOT exist at FileView load, watchChanges' inotify watch never attaches and
        // later creation/edits are missed forever (daemon can outlive the toggle file,
        // e.g. fresh boot before first click). A cheap periodic reload() on a tmpfs
        // file re-reads and, once present, fires onTextChanged → syncOpen(). Effectively
        // free; the watch path still gives instant updates when it works.
        Timer {
            interval: 400
            running: true
            repeat: true
            onTriggered: stateFile.reload()
        }

        Card {
            id: card
            wx: wx
            visible: opacity > 0.01
            opacity: win.open ? 1 : 0
            scale: win.open ? 1 : 0.96
            transformOrigin: Item.Top
            // Animation acts ONLY on the card (cosmetic, inside the fixed transparent
            // surface; Card has clip:true). Never feeds back into surface size.
            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on scale   { SpringAnimation { spring: 4.0; damping: 0.5; epsilon: 0.01 } }
        }
    }
}
