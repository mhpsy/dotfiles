import QtQuick
import ".."

// Word-of-the-day pill — reads from the WordData singleton.
//
// Same hover/PopupState contract as Weather: entering OR leaving the popup
// card keeps PopupState.wordOpen true (the card's own MouseArea calls
// openWord on enter), so the pill stays highlighted while the user is
// reading the card.
Rectangle {
    id: root
    readonly property bool active:  PopupState.wordOpen
    readonly property var  cur:     WordData.current || ({})
    readonly property var  posArr:  (cur && cur.pos && cur.pos.length) ? cur.pos : []

    radius: Theme.radius
    color:  active ? Theme.primary : Theme.surfaceContainerHigh
    implicitWidth:  row.implicitWidth + 2 * Theme.pad
    implicitHeight: Theme.barHeight - 8
    visible: !!cur.word
    Behavior on color { ColorAnimation { duration: 200; easing.type: Easing.OutQuad } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text:           root.cur.word || ""
            color:          root.active ? Theme.fgPrimaryContainer : Theme.fgSurface
            font.family:    Theme.uiFont
            font.pixelSize: 12
            font.bold:      true
            Behavior on color { ColorAnimation { duration: 200; easing.type: Easing.OutQuad } }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible:        root.posArr.length > 0
            text:           root.posArr.join(" ")
            color:          root.active ? Theme.fgPrimaryContainer : Theme.fgSurfaceVariant
            font.family:    Theme.uiFont
            font.pixelSize: 11
            Behavior on color { ColorAnimation { duration: 200; easing.type: Easing.OutQuad } }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text:           root.cur.meaning || ""
            color:          root.active ? Theme.fgPrimaryContainer : Theme.fgSurfaceVariant
            font.family:    Theme.uiFont
            font.pixelSize: 12
            Behavior on color { ColorAnimation { duration: 200; easing.type: Easing.OutQuad } }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape:  Qt.PointingHandCursor
        onEntered: PopupState.openWord()
        onExited:  PopupState.closeWord()
    }

    // Report pill screen-x to PopupState so the popup surface lands centered
    // on us. See Weather.qml for the coordinate-system rationale.
    function reportAnchor() {
        PopupState.wordAnchorX = mapToItem(null, width / 2, 0).x
    }
    onXChanged:     reportAnchor()
    onWidthChanged: reportAnchor()
    Component.onCompleted: reportAnchor()
}
