import QtQuick
import Quickshell.Io
import ".."

// CPU + RAM utilization pill — reads from SystemData singleton (top-processes
// telemetry lives there too, for the popup). Hover → SystemCard popup with
// per-process breakdown.
Rectangle {
    id: root
    readonly property bool active: PopupState.systemOpen

    radius:  Theme.radius
    color:   active ? Theme.primary : Theme.surfaceContainerHigh
    implicitWidth:  row.implicitWidth + 2 * Theme.pad
    implicitHeight: Theme.pillHeight
    Behavior on color { ColorAnimation { duration: 200; easing.type: Easing.OutQuad } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 10

        // CPU
        Row {
            spacing: 4
            anchors.verticalCenter: parent.verticalCenter
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: ""
                font.family:    Theme.glyphFont
                font.styleName: Theme.glyphStyle
                font.pixelSize: Theme.glyphSize
                color:          root.active ? Theme.fgPrimaryContainer : Theme.fgSurfaceVariant
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text:           SystemData.cpuPct + "%"
                font.family:    Theme.monoFont
                font.pixelSize: Theme.textSize
                color:          root.active ? Theme.fgPrimaryContainer : Theme.fgSurface
            }
        }
        // RAM
        Row {
            spacing: 4
            anchors.verticalCenter: parent.verticalCenter
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: ""
                font.family:    Theme.glyphFont
                font.styleName: Theme.glyphStyle
                font.pixelSize: Theme.glyphSize
                color:          root.active ? Theme.fgPrimaryContainer : Theme.fgSurfaceVariant
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text:           SystemData.ramPct + "%"
                font.family:    Theme.monoFont
                font.pixelSize: Theme.textSize
                color:          root.active ? Theme.fgPrimaryContainer : Theme.fgSurface
            }
        }
    }

    Process { id: launchHtop; command: ["bash", "-c", "kitty -e htop &"] }
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape:  Qt.PointingHandCursor
        onEntered: PopupState.openSystem()
        onExited:  PopupState.closeSystem()
        onClicked: launchHtop.running = true
    }

    function reportAnchor() { PopupState.systemAnchorX = mapToItem(null, width / 2, 0).x }
    onXChanged:            reportAnchor()
    onWidthChanged:        reportAnchor()
    Component.onCompleted: reportAnchor()
}
