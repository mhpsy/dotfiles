import QtQuick
import Quickshell.Hyprland
import ".."

// Hyprland special-workspace toggle. Matches waybar's style:
//
//   * min-width 64px regardless of state (no jitter on toggle).
//   * Per-SP active palette so each toggle reads as a distinct surface:
//       drawer        → secondary container
//       chat          → primary   container
//       entertainment → tertiary  container
//   * Inactive: dimmed text on the standard pill bg.
//   * Active: per-SP bg + matching fg, icon + small label (DEV/CHAT/DOCS)
//     packed inside the same 64px width.
Rectangle {
    id: root
    required property string name
    required property string icon
    required property string label

    readonly property bool active: SpecialWatcher.isActive(name)

    readonly property color activeBg:
          name === "drawer"  ? Theme.secondaryContainer
        : name === "chat"    ? Theme.primaryContainer
                             : Theme.tertiaryContainer
    readonly property color activeFg:
          name === "drawer"  ? Theme.fgSecondaryContainer
        : name === "chat"    ? Theme.fgPrimaryContainer
                             : Theme.fgTertiaryContainer

    color:  active ? activeBg : Theme.surfaceContainerHigh
    radius: Theme.radius
    // waybar uses min-width: 64 — fixed width prevents layout shift when
    // the label appears/disappears on toggle.
    implicitWidth:  Math.max(64, row.implicitWidth + 2 * Theme.pad)
    implicitHeight: Theme.pillHeight

    Behavior on color { ColorAnimation { duration: 180; easing.type: Easing.OutQuad } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text:           root.icon
            font.family:    Theme.glyphFont
            font.styleName: Theme.glyphStyle
            font.pixelSize: Theme.textSize
            color:          root.active ? root.activeFg : Theme.fgSurfaceVariant
            Behavior on color { ColorAnimation { duration: 180 } }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible:        root.active
            text:           root.label
            font.family:    Theme.uiFont
            font.pixelSize: Theme.textSize - 2
            font.bold:      true
            font.letterSpacing: 0.5
            color:          root.activeFg
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape:  Qt.PointingHandCursor
        onClicked: {
            Hyprland.dispatch("togglespecialworkspace " + root.name)
            SpecialWatcher.refresh()
        }
    }
}
