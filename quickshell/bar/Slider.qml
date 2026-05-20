import QtQuick
import "."

// Thin horizontal slider — reusable for Audio / Brightness popup cards.
// Click anywhere on track to jump; drag to scrub. Emits `moved` whenever
// the user changes the value (NOT when the bound `value` changes from
// external updates — that's a deliberate one-way binding for write only).
Item {
    id: root
    implicitWidth:  180
    implicitHeight: 22

    property real value: 0    // 0..1, set externally
    signal moved(real v)      // user dragged to v

    Rectangle {
        // Full track
        anchors {
            left:           parent.left
            right:          parent.right
            verticalCenter: parent.verticalCenter
        }
        height: 4
        radius: 2
        color:  Theme.surfaceContainerHigh
    }
    Rectangle {
        // Filled portion
        anchors {
            left:           parent.left
            verticalCenter: parent.verticalCenter
        }
        width:  parent.width * Math.max(0, Math.min(1, root.value))
        height: 4
        radius: 2
        color:  Theme.primary
    }
    Rectangle {
        // Handle
        anchors.verticalCenter: parent.verticalCenter
        x:      parent.width * Math.max(0, Math.min(1, root.value)) - 9
        width:  18
        height: 18
        radius: 9
        color:  Theme.primary
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        function applyAt(mx) {
            const v = Math.max(0, Math.min(1, mx / root.width))
            root.moved(v)
        }
        onPressed:           (m) => applyAt(m.x)
        onPositionChanged:   (m) => { if (pressed) applyAt(m.x) }
    }
}
