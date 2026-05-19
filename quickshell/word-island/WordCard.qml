import QtQuick
import QtQuick.Layouts
import "."

Rectangle {
    id: card
    property var words
    readonly property var cur: (words && words.current) ? words.current : ({})
    readonly property var todays: (words && words.today) ? words.today : []

    implicitWidth: 460
    implicitHeight: col.implicitHeight + 40
    radius: Theme.radius
    border.color: Theme.stroke
    border.width: 1
    gradient: Gradient {
        GradientStop { position: 0.0; color: Theme.cardBg1 }
        GradientStop { position: 1.0; color: Theme.cardBg2 }
    }
    clip: true

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        z: -1
        color: Theme.tintFor(card.cur.pos)
        Behavior on color { ColorAnimation { duration: 300; easing.type: Easing.OutCubic } }
    }

    ColumnLayout {
        id: col
        z: 1
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20 }
        spacing: 12

        ColumnLayout {
            spacing: 2
            RowLayout {
                spacing: 10
                Text { text: card.cur.word || "--"; color: Theme.accent; font.family: Theme.uiFont; font.pixelSize: 34; font.bold: true }
                Text { text: (card.cur.pos && card.cur.pos.length ? card.cur.pos.join(" ") : ""); color: Theme.fgFaint; font.family: Theme.uiFont; font.pixelSize: 14 }
                Item { Layout.fillWidth: true }
                Rectangle {
                    id: speakBtn
                    implicitWidth: 34; implicitHeight: 28; radius: 8
                    color: Theme.chipBg
                    Text { anchors.centerIn: parent; text: ""; font.family: Theme.glyphFont; font.styleName: Theme.glyphStyle; font.pixelSize: 15; color: Theme.fg }
                }
            }
            Text { text: card.cur.phonetic || ""; color: Theme.fgDim; font.family: Theme.uiFont; font.pixelSize: 13 }
            Text { text: card.cur.meaning || "--"; color: Theme.fg; font.family: Theme.uiFont; font.pixelSize: 16; Layout.fillWidth: true; wrapMode: Text.WordWrap }
            Text { text: card.cur.example || ""; color: Theme.fgFaint; font.family: Theme.uiFont; font.pixelSize: 12; Layout.fillWidth: true; wrapMode: Text.WordWrap }
        }

        Text { text: "今日单词"; color: Theme.fgFaint; font.family: Theme.uiFont; font.pixelSize: 11 }

        Repeater {
            model: card.todays
            delegate: Rectangle {
                id: row
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: 34
                radius: 10
                color: modelData.current ? Theme.chipBg : "transparent"
                RowLayout {
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    spacing: 10
                    Text { text: modelData.word || "--"; color: modelData.current ? Theme.accent : Theme.fg; font.family: Theme.uiFont; font.pixelSize: 14; font.bold: modelData.current }
                    Text { text: modelData.meaning || ""; color: Theme.fgDim; font.family: Theme.uiFont; font.pixelSize: 12; Layout.fillWidth: true; elide: Text.ElideRight }
                }
            }
        }
    }
}
