import QtQuick
import ".."

// Caffeine / keep-awake pill — reads from CaffeineData singleton.
//
//   keepAwake = true  → hypridle is not running → display warm primary
//                        color (idle is blocked, screen stays on)
//   keepAwake = false → hypridle is running     → muted (idle allowed)
//
// Left-click toggles; hover opens CaffeineCard popup with state + the
// list of programs that are independently blocking idle.
Rectangle {
    id: root
    readonly property bool active: PopupState.caffeineOpen

    radius:  Theme.radius
    color:   active ? Theme.primary : Theme.surfaceContainerHigh
    implicitWidth:  icon.implicitWidth + 2 * Theme.pad
    implicitHeight: Theme.pillHeight
    Behavior on color { ColorAnimation { duration: 200; easing.type: Easing.OutQuad } }

    Text {
        id: icon
        anchors.centerIn: parent
        text:           ""
        font.family:    Theme.glyphFont
        font.styleName: Theme.glyphStyle
        font.pixelSize: Theme.glyphSize
        color:          (root.active
                          ? Theme.fgPrimaryContainer
                          : CaffeineData.keepAwake
                              ? Theme.primary
                              : Theme.fgSurfaceVariant)
        Behavior on color { ColorAnimation { duration: 200; easing.type: Easing.OutQuad } }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape:  Qt.PointingHandCursor
        onEntered: PopupState.openCaffeine()
        onExited:  PopupState.closeCaffeine()
        onClicked: CaffeineData.toggle()
    }

    function reportAnchor() { PopupState.caffeineAnchorX = mapToItem(null, width / 2, 0).x }
    onXChanged:            reportAnchor()
    onWidthChanged:        reportAnchor()
    Component.onCompleted: reportAnchor()
}
