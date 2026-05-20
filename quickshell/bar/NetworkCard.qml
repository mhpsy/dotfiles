import QtQuick
import QtQuick.Layouts
import "."

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
        spacing: 8

        // ---- header ----
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Text {
                text:           NetworkData.ifaceType === "wifi" ? "" : ""
                font.family:    Theme.glyphFont
                font.styleName: Theme.glyphStyle
                font.pixelSize: 18
                color:          NetworkData.connected ? Theme.primary : Theme.fgSurfaceVariant
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    text:           NetworkData.connected ? NetworkData.ifname : "未连接"
                    color:          Theme.fgSurface
                    font.family:    Theme.uiFont
                    font.pixelSize: 13
                    font.bold:      true
                }
                Text {
                    visible:        NetworkData.connected
                    text:           NetworkData.ipAddr || "—"
                    color:          Theme.fgSurfaceVariant
                    font.family:    Theme.monoFont
                    font.pixelSize: 11
                }
            }
            Text {
                visible:        NetworkData.ifaceType === "wifi"
                text:           NetworkData.signalPct + "%"
                color:          Theme.fgSurfaceVariant
                font.family:    Theme.monoFont
                font.pixelSize: 12
            }
        }

        // ---- bandwidth ----
        RowLayout {
            visible: NetworkData.connected
            Layout.fillWidth: true
            Layout.topMargin: 4
            spacing: 16

            // download
            RowLayout {
                spacing: 6
                Text {
                    text:           ""
                    font.family:    Theme.glyphFont
                    font.styleName: Theme.glyphStyle
                    font.pixelSize: 12
                    color:          Theme.primary
                }
                Text {
                    text:           NetworkData.fmtBytes(NetworkData.rxRate)
                    color:          Theme.fgSurface
                    font.family:    Theme.monoFont
                    font.pixelSize: 12
                }
            }
            // upload
            RowLayout {
                spacing: 6
                Text {
                    text:           ""
                    font.family:    Theme.glyphFont
                    font.styleName: Theme.glyphStyle
                    font.pixelSize: 12
                    color:          Theme.tertiary
                }
                Text {
                    text:           NetworkData.fmtBytes(NetworkData.txRate)
                    color:          Theme.fgSurface
                    font.family:    Theme.monoFont
                    font.pixelSize: 12
                }
            }
            Item { Layout.fillWidth: true }
        }
    }
}
