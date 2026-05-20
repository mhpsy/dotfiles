import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import ".."

// Normal-workspace pills (1, 2, 3, ...).
//
// Hyprland assigns NEGATIVE ids to "special" workspaces (drawer / chat /
// entertainment in this setup). They aren't switched by `workspace <id>` —
// they need `togglespecialworkspace <name>` — so we filter them out and let
// dedicated sp-* modules handle them (the existing waybar setup does the same).
//
// `items` is a JS array derived from Hyprland.workspaces; the binding re-runs
// when the underlying ObjectModel mutates (insert / remove). Sorting on id
// keeps the visual order stable regardless of insertion order.
RowLayout {
    id: root
    spacing: 4

    readonly property var items: {
        const ws = Hyprland.workspaces ? Hyprland.workspaces.values : []
        const out = []
        for (let i = 0; i < ws.length; i++) {
            if (ws[i] && ws[i].id > 0) out.push(ws[i])
        }
        out.sort((a, b) => a.id - b.id)
        return out
    }

    Repeater {
        model: root.items

        delegate: Rectangle {
            id: pill
            required property var modelData

            readonly property bool isActive: modelData
                                             && (modelData.active === true
                                                 || (Hyprland.focusedWorkspace
                                                     && Hyprland.focusedWorkspace.id === modelData.id))

            Layout.preferredWidth:  isActive ? 28 : 22
            Layout.preferredHeight: Theme.barHeight - 14
            radius: height / 2
            color:  isActive ? Theme.primary : Theme.surfaceContainerHigh

            Behavior on Layout.preferredWidth { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            Behavior on color                 { ColorAnimation  { duration: 150 } }

            Text {
                anchors.centerIn: parent
                text:        modelData ? modelData.id : ""
                color:       pill.isActive ? Theme.fgPrimaryContainer : Theme.fgSurfaceVariant
                font.family: Theme.uiFont
                font.pixelSize: 11
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Hyprland.dispatch("workspace " + modelData.id)
            }
        }
    }
}
