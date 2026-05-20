import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "."

// Updates popup — header with count, repo sections (pacman / AUR) listing
// pending packages. Click anywhere on the card to launch `yay` in a terminal
// for interactive upgrade.
Item {
    id: card
    implicitWidth: 360
    implicitHeight: col.implicitHeight + 28

    readonly property int maxRowsPerSection: 8

    Process { id: upgradeProc; command: ["bash", "-c", "kitty -e bash -c 'yay; read -n1 -s' &"] }

    ColumnLayout {
        id: col
        anchors {
            left:        parent.left
            right:       parent.right
            top:         parent.top
            margins:     14
        }
        spacing: 8

        // ---- header ----
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Text {
                text:           ""
                font.family:    Theme.glyphFont
                font.styleName: Theme.glyphStyle
                font.pixelSize: 18
                color:          Theme.primary
            }
            Text {
                Layout.fillWidth: true
                text:           UpdatesData.totalCount > 0
                                ? UpdatesData.totalCount + " 个待更新"
                                : "已最新"
                color:          Theme.fgSurface
                font.family:    Theme.uiFont
                font.pixelSize: 14
                font.bold:      true
            }
        }

        // ---- pacman section ----
        ColumnLayout {
            Layout.fillWidth: true
            visible: UpdatesData.pacmanCount > 0
            spacing: 2
            Text {
                text:           "Pacman · " + UpdatesData.pacmanCount
                color:          Theme.fgSurfaceVariant
                font.family:    Theme.uiFont
                font.pixelSize: 11
                font.letterSpacing: 1
                Layout.topMargin: 4
            }
            Repeater {
                model: UpdatesData.pacmanList.slice(0, card.maxRowsPerSection)
                delegate: Text {
                    required property var modelData
                    Layout.fillWidth: true
                    text:           modelData
                    color:          Theme.fgSurface
                    font.family:    Theme.monoFont
                    font.pixelSize: 10
                    elide:          Text.ElideRight
                }
            }
            Text {
                visible: UpdatesData.pacmanCount > card.maxRowsPerSection
                text:    "… 还有 " + (UpdatesData.pacmanCount - card.maxRowsPerSection) + " 个"
                color:   Theme.fgSurfaceVariant
                font.family: Theme.uiFont
                font.pixelSize: 10
                font.italic: true
            }
        }

        // ---- AUR section ----
        ColumnLayout {
            Layout.fillWidth: true
            visible: UpdatesData.aurCount > 0
            spacing: 2
            Text {
                text:           "AUR · " + UpdatesData.aurCount
                color:          Theme.fgSurfaceVariant
                font.family:    Theme.uiFont
                font.pixelSize: 11
                font.letterSpacing: 1
                Layout.topMargin: 4
            }
            Repeater {
                model: UpdatesData.aurList.slice(0, card.maxRowsPerSection)
                delegate: Text {
                    required property var modelData
                    Layout.fillWidth: true
                    text:           modelData
                    color:          Theme.fgSurface
                    font.family:    Theme.monoFont
                    font.pixelSize: 10
                    elide:          Text.ElideRight
                }
            }
            Text {
                visible: UpdatesData.aurCount > card.maxRowsPerSection
                text:    "… 还有 " + (UpdatesData.aurCount - card.maxRowsPerSection) + " 个"
                color:   Theme.fgSurfaceVariant
                font.family: Theme.uiFont
                font.pixelSize: 10
                font.italic: true
            }
        }

        // ---- action hint ----
        Text {
            Layout.fillWidth: true
            Layout.topMargin: 6
            visible: UpdatesData.totalCount > 0
            text:    "点击运行 yay"
            color:   Theme.fgSurfaceVariant
            font.family: Theme.uiFont
            font.pixelSize: 10
            font.italic: true
            horizontalAlignment: Text.AlignRight
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape:  Qt.PointingHandCursor
        enabled:      UpdatesData.totalCount > 0
        onClicked:    upgradeProc.running = true
    }
}
