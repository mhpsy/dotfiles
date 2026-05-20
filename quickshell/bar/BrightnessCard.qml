import QtQuick
import "."

Item {
    id: card
    implicitWidth:  280
    implicitHeight: 56

    Row {
        anchors {
            fill:        parent
            leftMargin:  16
            rightMargin: 16
            topMargin:   4
            bottomMargin:4
        }
        spacing: 12

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text:           ""            // fa-sun
            font.family:    Theme.glyphFont
            font.styleName: Theme.glyphStyle
            font.pixelSize: 16
            color:          Theme.primary
        }

        Slider {
            anchors.verticalCenter: parent.verticalCenter
            width:   170
            value:   BrightnessData.percent / 100
            onMoved: (v) => BrightnessData.setPercent(v * 100)
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text:           BrightnessData.percent + "%"
            color:          Theme.fgSurface
            font.family:    Theme.monoFont
            font.pixelSize: 12
            width:          36
            horizontalAlignment: Text.AlignRight
        }
    }
}
