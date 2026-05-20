import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import ".."

// Workspaces — waybar style:
//
//   inactive → transparent bg, just the number in fg
//   active   → primary_container bg, fg flipped to on_primary, min-width 40
//   hover    → same look as active
//
// Persistent: workspaces 1..N are always rendered even if Hyprland hasn't
// allocated them yet (matches waybar's `persistent-workspaces: "*": N`).
// Non-existent placeholders are dimmed so real-but-inactive workspaces
// still pop.
RowLayout {
    id: root
    spacing: 3

    readonly property int persistentCount: 5

    readonly property var items: {
        const real    = Hyprland.workspaces ? Hyprland.workspaces.values : []
        const realMap = ({})
        for (let i = 0; i < real.length; i++) {
            const w = real[i]
            if (w && w.id > 0) realMap[w.id] = w
        }
        const idSet = new Set()
        for (let i = 1; i <= root.persistentCount; i++) idSet.add(i)
        for (const k in realMap) idSet.add(parseInt(k))
        const ids = Array.from(idSet).sort((a, b) => a - b)
        const out = []
        for (const id of ids) {
            const w = realMap[id] || null
            out.push({
                id:       id,
                ws:       w,
                isReal:   w !== null,
                isActive: w !== null && w.active === true
            })
        }
        return out
    }

    Repeater {
        model: root.items

        delegate: Rectangle {
            id: pill
            required property var modelData

            readonly property bool isActive: modelData && modelData.isActive
            readonly property bool isReal:   modelData && modelData.isReal
            // hover counts as "active-look" — matches waybar's button:hover.
            readonly property bool litUp:    isActive || ma.containsMouse

            // Active: fixed 40px (waybar min-width). Inactive: tight around
            // the digit (pad 8 each side, never narrower than pillHeight).
            Layout.preferredWidth: isActive
                                       ? 40
                                       : Math.max(label.implicitWidth + 16, Theme.pillHeight)
            Layout.preferredHeight: Theme.pillHeight
            radius: 15

            color:   litUp ? Theme.primaryContainer : "transparent"
            opacity: (isActive || isReal) ? 1.0 : 0.55

            Behavior on Layout.preferredWidth { NumberAnimation { duration: 300; easing.type: Easing.InOutQuad } }
            Behavior on color                 { ColorAnimation  { duration: 250 } }
            Behavior on opacity               { NumberAnimation { duration: 250 } }

            Text {
                id: label
                anchors.centerIn: parent
                text:        modelData ? modelData.id : ""
                color:       pill.litUp ? Theme.fgPrimaryContainer : Theme.fgSurface
                font.family: Theme.uiFont
                font.pixelSize: Theme.textSize
                font.bold:   true
                Behavior on color { ColorAnimation { duration: 250 } }
            }

            MouseArea {
                id: ma
                anchors.fill: parent
                hoverEnabled: true
                cursorShape:  Qt.PointingHandCursor
                onClicked: Hyprland.dispatch("workspace " + modelData.id)
            }
        }
    }
}
