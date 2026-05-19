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

        Item {
            id: stack
            width: Math.max(pill.implicitWidth, win.expanded ? card.implicitWidth : 0)
            height: pill.implicitHeight + (win.expanded ? card.implicitHeight + 6 : 0)
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
                y: pill.implicitHeight + 6
                width: implicitWidth
                visible: opacity > 0.01
                opacity: win.expanded ? 1 : 0
                scale: win.expanded ? 1 : 0.96
                transformOrigin: Item.Top
                Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                Behavior on scale   { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }

                HoverHandler { id: cardHover }
            }

            Timer {
                id: collapseTimer
                interval: 350
                onTriggered: if (!cardHover.hovered && !pillHover.hovered) win.expanded = false
            }
            HoverHandler { id: pillHover; target: pill }
            Connections {
                target: cardHover
                function onHoveredChanged() {
                    if (win.expanded && !cardHover.hovered) collapseTimer.restart()
                    else collapseTimer.stop()
                }
            }
        }
    }
}
