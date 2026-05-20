import QtQuick
import QtQuick.Layouts
import "."

// Connected Bluetooth devices popup.
// Each row: device name + battery (if reported by the device).
// When nothing is connected, shows a friendly message.
Item {
    id: card
    implicitWidth:  320
    implicitHeight: col.implicitHeight + 28

    ColumnLayout {
        id: col
        anchors {
            left:    parent.left
            right:   parent.right
            top:     parent.top
            margins: 14
        }
        spacing: 10

        // ---- header ----
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Text {
                text:           ""
                font.family:    Theme.glyphFont
                font.styleName: Theme.glyphStyle
                font.pixelSize: 18
                color:          BluetoothData.powered ? Theme.primary : Theme.fgSurfaceVariant
            }
            Text {
                Layout.fillWidth: true
                text: !BluetoothData.powered ? "Bluetooth 已关闭"
                    : BluetoothData.connectedCount > 0
                        ? "已连接 " + BluetoothData.connectedCount + " 个设备"
                        : "未连接设备"
                color:       Theme.fgSurface
                font.family: Theme.uiFont
                font.pixelSize: 14
                font.bold:   true
            }
        }

        // ---- device rows ----
        Repeater {
            model: BluetoothData.connectedDevices
            delegate: Rectangle {
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                radius: 10
                color: Theme.surfaceContainerHigh

                RowLayout {
                    anchors {
                        fill:        parent
                        leftMargin:  12
                        rightMargin: 12
                    }
                    spacing: 10

                    Text {
                        Layout.fillWidth: true
                        text:           modelData.name
                        color:          Theme.fgSurface
                        font.family:    Theme.uiFont
                        font.pixelSize: 12
                        elide:          Text.ElideRight
                    }

                    // Battery cluster — only shown if device reports it.
                    Item {
                        visible: modelData.battery !== null
                        implicitWidth:  batRow.implicitWidth
                        implicitHeight: batRow.implicitHeight
                        RowLayout {
                            id: batRow
                            anchors.centerIn: parent
                            spacing: 4
                            Text {
                                text:           ""
                                font.family:    Theme.glyphFont
                                font.styleName: Theme.glyphStyle
                                font.pixelSize: 11
                                color:          (modelData.battery !== null && modelData.battery < 20)
                                                  ? Theme.error
                                                  : Theme.fgSurfaceVariant
                            }
                            Text {
                                text:           (modelData.battery ?? "?") + "%"
                                color:          Theme.fgSurface
                                font.family:    Theme.monoFont
                                font.pixelSize: 11
                            }
                        }
                    }
                }
            }
        }
    }
}
