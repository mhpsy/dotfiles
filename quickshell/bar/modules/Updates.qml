import QtQuick
import ".."

// Updates pill — count of pending pacman + AUR updates. Reads from
// UpdatesData singleton (which polls in the background). Hidden when 0.
// Hover → UpdatesCard popup with full package list.
Rectangle {
    id: root
    readonly property bool active: PopupState.updatesOpen

    visible: UpdatesData.totalCount > 0
    radius:  Theme.radius
    color:   active ? Theme.primary : Theme.surfaceContainerHigh
    implicitWidth:  visible ? row.implicitWidth + 2 * Theme.pad : 0
    implicitHeight: Theme.barHeight - 8
    Behavior on color { ColorAnimation { duration: 200; easing.type: Easing.OutQuad } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text:           ""
            font.family:    Theme.glyphFont
            font.styleName: Theme.glyphStyle
            font.pixelSize: 11
            color:          root.active ? Theme.fgPrimaryContainer : Theme.fgSurfaceVariant
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text:           UpdatesData.totalCount.toString()
            font.family:    Theme.uiFont
            font.pixelSize: 12
            color:          root.active ? Theme.fgPrimaryContainer : Theme.fgSurface
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape:  Qt.PointingHandCursor
        onEntered: PopupState.openUpdates()
        onExited:  PopupState.closeUpdates()
        onClicked: UpdatesData.refresh()
    }

    function reportAnchor() { PopupState.updatesAnchorX = mapToItem(null, width / 2, 0).x }
    onXChanged:            reportAnchor()
    onWidthChanged:        reportAnchor()
    Component.onCompleted: reportAnchor()
}
