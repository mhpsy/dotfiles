import QtQuick
import QtQuick.Layouts
import "."

// CPU + RAM detail popup. Two columns: CPU usage + top 5 by CPU, RAM usage
// + top 5 by RAM. Process names elide when long.
Item {
    id: card
    implicitWidth:  420
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

        // ---- summary bar ----
        RowLayout {
            Layout.fillWidth: true
            spacing: 18

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                RowLayout {
                    spacing: 6
                    Text {
                        text:           ""
                        font.family:    Theme.glyphFont
                        font.styleName: Theme.glyphStyle
                        font.pixelSize: 13
                        color:          Theme.primary
                    }
                    Text {
                        text:           "CPU"
                        color:          Theme.fgSurfaceVariant
                        font.family:    Theme.uiFont
                        font.pixelSize: 11
                        font.letterSpacing: 1
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text:           SystemData.cpuPct + "%"
                        color:          Theme.fgSurface
                        font.family:    Theme.monoFont
                        font.pixelSize: 14
                        font.bold:      true
                    }
                }
                // tiny bar
                Rectangle {
                    Layout.fillWidth: true
                    height: 3
                    radius: 1.5
                    color: Theme.surfaceContainerHigh
                    Rectangle {
                        anchors {
                            left:   parent.left
                            top:    parent.top
                            bottom: parent.bottom
                        }
                        width: parent.width * SystemData.cpuPct / 100
                        radius: 1.5
                        color: Theme.primary
                        Behavior on width { NumberAnimation { duration: 250 } }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                RowLayout {
                    spacing: 6
                    Text {
                        text:           ""
                        font.family:    Theme.glyphFont
                        font.styleName: Theme.glyphStyle
                        font.pixelSize: 13
                        color:          Theme.tertiary
                    }
                    Text {
                        text:           "RAM"
                        color:          Theme.fgSurfaceVariant
                        font.family:    Theme.uiFont
                        font.pixelSize: 11
                        font.letterSpacing: 1
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text:           SystemData.ramPct + "%"
                        color:          Theme.fgSurface
                        font.family:    Theme.monoFont
                        font.pixelSize: 14
                        font.bold:      true
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    height: 3
                    radius: 1.5
                    color: Theme.surfaceContainerHigh
                    Rectangle {
                        anchors {
                            left:   parent.left
                            top:    parent.top
                            bottom: parent.bottom
                        }
                        width: parent.width * SystemData.ramPct / 100
                        radius: 1.5
                        color: Theme.tertiary
                        Behavior on width { NumberAnimation { duration: 250 } }
                    }
                }
            }
        }

        // ---- top processes ----
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            spacing: 18

            // Top CPU
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                Text {
                    text: "TOP CPU"
                    color: Theme.fgSurfaceVariant
                    font.family: Theme.uiFont
                    font.pixelSize: 10
                    font.letterSpacing: 1
                }
                Repeater {
                    model: SystemData.topCpu
                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 6
                        Text {
                            Layout.fillWidth: true
                            text:           modelData.cmd
                            color:          Theme.fgSurface
                            font.family:    Theme.monoFont
                            font.pixelSize: 11
                            elide:          Text.ElideRight
                        }
                        Text {
                            text:           modelData.pct.toFixed(1)
                            color:          Theme.primary
                            font.family:    Theme.monoFont
                            font.pixelSize: 11
                        }
                    }
                }
            }

            // Top RAM
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                Text {
                    text: "TOP RAM"
                    color: Theme.fgSurfaceVariant
                    font.family: Theme.uiFont
                    font.pixelSize: 10
                    font.letterSpacing: 1
                }
                Repeater {
                    model: SystemData.topRam
                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 6
                        Text {
                            Layout.fillWidth: true
                            text:           modelData.cmd
                            color:          Theme.fgSurface
                            font.family:    Theme.monoFont
                            font.pixelSize: 11
                            elide:          Text.ElideRight
                        }
                        Text {
                            text:           modelData.pct.toFixed(1)
                            color:          Theme.tertiary
                            font.family:    Theme.monoFont
                            font.pixelSize: 11
                        }
                    }
                }
            }
        }
    }
}
