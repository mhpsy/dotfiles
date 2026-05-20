import QtQuick
import QtQuick.Layouts
import Quickshell.Wayland
import ".."

// Active window title.
//
// ToplevelManager (wlr-foreign-toplevel-management) is compositor-agnostic and
// available on Hyprland — easier than Hyprland.focusedClient because it gives
// us a stable .title property without IPC polling.
//
// Width caps via Layout.maximumWidth from the parent (Bar.qml); the Text uses
// elide=Right to truncate long titles cleanly.
Rectangle {
    id: root
    color: "transparent"

    readonly property var tl: ToplevelManager.activeToplevel
    readonly property string titleText: tl ? (tl.title || tl.appId || "") : ""

    visible: titleText.length > 0
    implicitWidth:  Math.min(label.implicitWidth + 2 * Theme.pad, 400)
    implicitHeight: Theme.pillHeight

    Text {
        id: label
        anchors.fill:        parent
        anchors.leftMargin:  Theme.pad
        anchors.rightMargin: Theme.pad
        verticalAlignment:   Text.AlignVCenter
        elide:               Text.ElideRight
        text:                root.titleText
        color:               Theme.fgSurface
        font.family:         Theme.uiFont
        font.pixelSize:      Theme.textSize
    }
}
