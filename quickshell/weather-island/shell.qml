import QtQuick
import Quickshell
import Quickshell.Wayland
import "."

ShellRoot {
    WlrLayershell {
        id: win
        anchors {
            top: true
            left: true
        }
        margins.left: 120
        margins.top: 0
        exclusiveZone: 0
        color: "transparent"
        layer: WlrLayer.Overlay
        keyboardFocus: WlrKeyboardFocus.None
        namespace: "qs-weather-island"

        implicitWidth: stack.width
        implicitHeight: stack.height

        mask: Region { item: stack }

        WeatherData { id: wx }
        property bool expanded: false
        onExpandedChanged: if (!expanded) collapseTimer.stop()   // any collapse cancels a pending auto-collapse (covers manual + external)

        Item {
            id: stack
            width: Math.max(pill.implicitWidth, win.expanded ? card.implicitWidth : 0)
            height: pill.implicitHeight + (win.expanded ? card.implicitHeight + 6 : 0)
            // auto-collapse only when expanded AND the pointer is off BOTH pill and card
            function evalCollapse() {
                if (win.expanded && !cardHover.hovered && !pillHover.hovered) collapseTimer.restart()
                else collapseTimer.stop()
            }
            // spring/damping tuned: snappy elastic, minimal bounce
            Behavior on width  { SpringAnimation { spring: 3.2; damping: 0.28; epsilon: 0.5 } }
            Behavior on height { SpringAnimation { spring: 3.2; damping: 0.28; epsilon: 0.5 } }

            Pill {
                id: pill
                wx: wx
                onToggle: win.expanded = !win.expanded
            }

            Card {
                id: card
                wx: wx
                y: pill.implicitHeight + 6   // 6px gap between pill and card
                width: implicitWidth
                visible: opacity > 0.01
                opacity: win.expanded ? 1 : 0
                scale: win.expanded ? 1 : 0.96
                transformOrigin: Item.Top
                Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                Behavior on scale   { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

                HoverHandler { id: cardHover }
            }

            Timer {
                id: collapseTimer
                interval: 350   // 350ms grace before auto-collapse when pointer leaves
                onTriggered: if (!cardHover.hovered && !pillHover.hovered) win.expanded = false
            }
            HoverHandler { id: pillHover; target: pill }
            Connections {
                target: cardHover
                function onHoveredChanged() { stack.evalCollapse() }
            }
            Connections {
                target: pillHover
                function onHoveredChanged() { stack.evalCollapse() }
            }
        }
    }
}
