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
        margins.top: 3
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        layer: WlrLayer.Overlay
        keyboardFocus: WlrKeyboardFocus.None
        namespace: "qs-weather-island"

        // FIXED Wayland surface = the expanded bounding box. NEVER animated.
        // Changes only when weather data updates card.implicitHeight (~15min),
        // never during expand/collapse → zero per-frame surface reconfigure.
        implicitWidth: Math.max(pill.implicitWidth, card.implicitWidth)
        implicitHeight: pill.implicitHeight + 6 + card.implicitHeight

        // State-driven mask (NOT spring-driven). Collapsed → input region is
        // only the pill rect (rest of the big transparent surface passes
        // clicks through = NO dead zone). Expanded → full stack interactive.
        // Switches discretely on `expanded` (cheap set_input_region, no
        // buffer/geometry reconfigure, no visual change).
        mask: Region { item: win.expanded ? stack : pill }

        WeatherData { id: wx }
        property bool expanded: false
        onExpandedChanged: if (!expanded) collapseTimer.stop()   // any collapse cancels a pending auto-collapse (covers manual + external)

        Item {
            id: stack
            // FIXED content area = surface size. NO spring/Behavior here.
            width: win.implicitWidth
            height: win.implicitHeight
            // auto-collapse only when expanded AND the pointer is off BOTH pill and card
            function evalCollapse() {
                if (win.expanded && !cardHover.hovered && !pillHover.hovered) collapseTimer.restart()
                else collapseTimer.stop()
            }

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
                // Elastic reveal lives ONLY on the card (cosmetic, inside the
                // fixed transparent surface — any overshoot is harmless clipped
                // pixels, NO Wayland reconfigure). scale bounded ~0.96..~1.05
                // so it cannot collapse anything through zero. Card has
                // clip:true so scaled content stays in rounded bounds.
                Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                Behavior on scale   { SpringAnimation { spring: 4.0; damping: 0.5; epsilon: 0.01 } }

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
