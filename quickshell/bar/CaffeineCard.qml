import QtQuick
import QtQuick.Layouts
import "."

// Caffeine popup card.
//
// Top row: state label + big toggle button (explicit click target — the
// pill's MouseArea also toggles, but the button reads as the primary action).
// Bottom: list of idle inhibitors currently active (browsers playing video,
// screen-share tools, etc) so you can see WHY the screen is staying on if
// caffeine itself is OFF.
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
        spacing: 12

        // ---- header: status + toggle ----
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Text {
                text:           ""
                font.family:    Theme.glyphFont
                font.styleName: Theme.glyphStyle
                font.pixelSize: 22
                color:          CaffeineData.keepAwake ? Theme.primary : Theme.fgSurfaceVariant
                Behavior on color { ColorAnimation { duration: 200 } }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    text:           CaffeineData.keepAwake ? "保持唤醒" : "允许休眠"
                    color:          Theme.fgSurface
                    font.family:    Theme.uiFont
                    font.pixelSize: 14
                    font.bold:      true
                }
                Text {
                    text:           "hypridle " + (CaffeineData.keepAwake ? "未运行" : "运行中")
                    color:          Theme.fgSurfaceVariant
                    font.family:    Theme.uiFont
                    font.pixelSize: 11
                }
            }
            // toggle button
            Rectangle {
                Layout.preferredWidth:  56
                Layout.preferredHeight: 28
                radius: 14
                color:  CaffeineData.keepAwake ? Theme.primary : Theme.surfaceContainerHigh
                Behavior on color { ColorAnimation { duration: 200 } }
                Text {
                    anchors.centerIn: parent
                    text:           CaffeineData.keepAwake ? "ON" : "OFF"
                    color:          CaffeineData.keepAwake ? Theme.fgPrimaryContainer : Theme.fgSurfaceVariant
                    font.family:    Theme.uiFont
                    font.pixelSize: 12
                    font.bold:      true
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape:  Qt.PointingHandCursor
                    onClicked:    CaffeineData.toggle()
                }
            }
        }

        // ---- inhibitor section ----
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Theme.outline
            opacity: 0.2
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            Text {
                text:    CaffeineData.inhibitors.length > 0
                            ? "阻止熄屏的程序 · " + CaffeineData.inhibitors.length
                            : "暂无外部 inhibitor"
                color:   Theme.fgSurfaceVariant
                font.family: Theme.uiFont
                font.pixelSize: 11
                font.letterSpacing: 1
            }

            Repeater {
                model: CaffeineData.inhibitors
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: row.implicitHeight + 10
                    radius: 8
                    color: Theme.surfaceContainerHigh

                    RowLayout {
                        id: row
                        anchors {
                            fill:        parent
                            leftMargin:  10
                            rightMargin: 10
                            topMargin:    5
                            bottomMargin: 5
                        }
                        spacing: 8
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Text {
                                text:        modelData.who
                                color:       Theme.fgSurface
                                font.family: Theme.uiFont
                                font.pixelSize: 12
                                font.bold:   true
                                elide:       Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Text {
                                visible:        (modelData.why || "").length > 0
                                text:           modelData.why
                                color:          Theme.fgSurfaceVariant
                                font.family:    Theme.uiFont
                                font.pixelSize: 10
                                elide:          Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                        Text {
                            text:           modelData.what
                            color:          Theme.fgSurfaceVariant
                            font.family:    Theme.monoFont
                            font.pixelSize: 9
                        }
                    }
                }
            }

            Text {
                visible: CaffeineData.inhibitors.length === 0
                text:    "无应用阻止熄屏 — 唤醒由本开关控制"
                color:   Theme.fgSurfaceVariant
                font.family:    Theme.uiFont
                font.pixelSize: 10
                font.italic:    true
                Layout.topMargin: 2
            }
        }
    }
}
