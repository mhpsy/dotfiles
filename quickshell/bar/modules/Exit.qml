import QtQuick
import Quickshell.Io
import ".."

// Exit / session pill.
//
//   left-click  → wlogout (full power menu)
//   right-click → hyprlock (lock screen immediately)
//
// Same bindings as waybar's custom/exit.
Rectangle {
    id: root
    radius:  Theme.radius
    color:   Theme.surfaceContainerHigh
    implicitWidth:  icon.implicitWidth + 2 * Theme.pad
    implicitHeight: Theme.pillHeight

    Text {
        id: icon
        anchors.centerIn: parent
        text: ""   // fa-power-off
        font.family:    Theme.glyphFont
        font.styleName: Theme.glyphStyle
        font.pixelSize: Theme.textSize
        color:          Theme.fgSurfaceVariant
    }

    Process { id: wlogoutProc; command: ["bash", "-c", "cd ~/.config/wlogout && wlogout &"] }
    Process { id: hyprlockProc; command: ["bash", "-c", "hyprlock &"] }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (e) => {
            if (e.button === Qt.LeftButton) wlogoutProc.running = true
            else                            hyprlockProc.running = true
        }
    }
}
