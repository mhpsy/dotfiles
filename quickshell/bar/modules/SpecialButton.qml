import QtQuick
import Quickshell.Hyprland
import ".."

// One toggle for a Hyprland "special" workspace (drawer / chat / entertainment).
//
// Active state comes from SpecialWatcher (which polls hyprctl + listens to
// hyprland events, mirroring how waybar's special-workspace.sh tracks it).
// HyprlandWorkspace.active does NOT work for special workspaces — that flag
// means "focused on its monitor", which is never true for an overlay.
Rectangle {
    id: root
    required property string name
    required property string icon

    readonly property bool active: SpecialWatcher.isActive(name)

    color:  active ? Theme.primary : Theme.surfaceContainerHigh
    radius: Theme.radius
    implicitWidth:  Theme.barHeight - 8
    implicitHeight: Theme.barHeight - 8

    Behavior on color { ColorAnimation { duration: 150 } }

    Text {
        anchors.centerIn: parent
        text:           root.icon
        font.family:    Theme.glyphFont
        font.styleName: Theme.glyphStyle
        font.pixelSize: 12
        color:          root.active ? Theme.fgPrimaryContainer : Theme.fgSurfaceVariant
    }

    MouseArea {
        anchors.fill: parent
        cursorShape:  Qt.PointingHandCursor
        onClicked: {
            Hyprland.dispatch("togglespecialworkspace " + root.name)
            // Snap UI without waiting for the hyprland event roundtrip.
            SpecialWatcher.refresh()
        }
    }
}
