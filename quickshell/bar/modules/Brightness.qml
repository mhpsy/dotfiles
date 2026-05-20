import QtQuick
import ".."

// Backlight brightness pill — reads from BrightnessData singleton (which
// delegates to ~/.config/waybar/brightness.sh: brightnessctl for laptop
// panels, ddcutil for external DDC/CI monitors).
//
// Interactions:
//   hover       → BrightnessCard popup with slider
//   scroll up   → BrightnessData.up()   (+5%)
//   scroll down → BrightnessData.down() (-5%)
Rectangle {
    id: root
    readonly property bool active: PopupState.brightnessOpen

    radius:  Theme.radius
    color:   active ? Theme.primary : Theme.surfaceContainerHigh
    implicitWidth:  row.implicitWidth + 2 * Theme.pad
    implicitHeight: Theme.pillHeight
    Behavior on color { ColorAnimation { duration: 200; easing.type: Easing.OutQuad } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text:           ""                // fa-sun
            font.family:    Theme.glyphFont
            font.styleName: Theme.glyphStyle
            font.pixelSize: Theme.glyphSize
            color:          root.active ? Theme.fgPrimaryContainer : Theme.fgSurfaceVariant
            Behavior on color { ColorAnimation { duration: 200; easing.type: Easing.OutQuad } }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text:           BrightnessData.percent + "%"
            font.family:    Theme.uiFont
            font.pixelSize: Theme.textSize
            color:          root.active ? Theme.fgPrimaryContainer : Theme.fgSurface
            Behavior on color { ColorAnimation { duration: 200; easing.type: Easing.OutQuad } }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: PopupState.openBrightness()
        onExited:  PopupState.closeBrightness()
        onWheel:   (w) => w.angleDelta.y > 0 ? BrightnessData.up() : BrightnessData.down()
    }

    function reportAnchor() {
        PopupState.brightnessAnchorX = mapToItem(null, width / 2, 0).x
    }
    onXChanged:     reportAnchor()
    onWidthChanged: reportAnchor()
    Component.onCompleted: reportAnchor()
}
