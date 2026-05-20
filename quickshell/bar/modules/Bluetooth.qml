import QtQuick
import Quickshell.Io
import ".."

// Bluetooth pill — reads from BluetoothData singleton.
//
// Display:
//   1 device connected → show that device's battery %
//   N devices          → show count
//   off / no devices   → icon only (dimmer)
//
// Interactions:
//   hover       → BluetoothCard popup with device list + batteries
//   left-click  → ghostty -e bluetuith  (terminal TUI manager — matches waybar)
//   right-click → blueman-manager (if installed)
Rectangle {
    id: root
    readonly property bool active: PopupState.bluetoothOpen
    readonly property var  single: BluetoothData.singleDevice
    readonly property int  count:  BluetoothData.connectedCount

    radius:  Theme.radius
    color:   active ? Theme.primary : Theme.surfaceContainerHigh
    implicitWidth:  row.implicitWidth + 2 * Theme.pad
    implicitHeight: Theme.pillHeight
    opacity: BluetoothData.powered ? 1.0 : 0.55
    Behavior on color { ColorAnimation { duration: 200; easing.type: Easing.OutQuad } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 4
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text:           ""
            font.family:    Theme.glyphFont
            font.styleName: Theme.glyphStyle
            font.pixelSize: Theme.textSize
            color:          (root.active ? Theme.fgPrimaryContainer
                            : root.count > 0 ? Theme.primary
                            : Theme.fgSurfaceVariant)
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible:        root.count > 0
            text:           root.single && root.single.battery !== null
                              ? root.single.battery + "%"
                              : root.count.toString()
            font.family:    Theme.uiFont
            font.pixelSize: Theme.glyphSize
            color:          root.active ? Theme.fgPrimaryContainer : Theme.fgSurface
        }
    }

    Process { id: actionProc }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape:  Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onEntered: PopupState.openBluetooth()
        onExited:  PopupState.closeBluetooth()
        onClicked: (e) => {
            if (e.button === Qt.RightButton) {
                actionProc.command = ["bash", "-c", "blueman-manager &"]
            } else {
                // Match waybar: open bluetuith in a terminal.
                actionProc.command = ["bash", "-c",
                    "(ghostty -e bluetuith 2>/dev/null || kitty -e bluetuith) &"]
            }
            actionProc.running = false
            actionProc.running = true
        }
    }

    function reportAnchor() { PopupState.bluetoothAnchorX = mapToItem(null, width / 2, 0).x }
    onXChanged:     reportAnchor()
    onWidthChanged: reportAnchor()
    Component.onCompleted: reportAnchor()
}
