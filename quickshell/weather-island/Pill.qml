import QtQuick
import "."

Rectangle {
    id: pill
    property var wx
    signal toggle()
    implicitWidth: row.implicitWidth + 28
    implicitHeight: 34
    radius: height / 2
    color: Theme.cardBg1
    border.color: Theme.stroke
    border.width: 1

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 8
        Text {
            text: (pill.wx && pill.wx.current ? (pill.wx.current.icon || "") : "")
            font.family: Theme.glyphFont; font.pixelSize: 18; color: Theme.fg
        }
        Text {
            text: (pill.wx && pill.wx.current ? (pill.wx.current.temp || "--") : "--") + "°"
            font.family: Theme.uiFont; font.pixelSize: 15; font.bold: true; color: Theme.fg
        }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: pill.toggle()
    }
}
