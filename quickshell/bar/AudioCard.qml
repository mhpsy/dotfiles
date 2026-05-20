import QtQuick
import Quickshell.Services.Pipewire
import "."

// Compact audio popup card — icon · slider · percentage. PwObjectTracker
// keeps the default sink alive across graph rebuilds.
Item {
    id: card
    implicitWidth:  280
    implicitHeight: 56

    readonly property var  sink:    Pipewire.defaultAudioSink
    readonly property var  audio:   sink ? sink.audio : null
    readonly property bool muted:   audio ? audio.muted : false
    readonly property real volume:  audio ? Math.min(1, audio.volume) : 0
    readonly property int  percent: Math.round(volume * 100)

    PwObjectTracker { objects: card.sink ? [card.sink] : [] }

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
            text: card.muted ? "" : ""    // mute / volume-high
            font.family:    Theme.glyphFont
            font.styleName: Theme.glyphStyle
            font.pixelSize: 16
            color:          card.muted ? Theme.error : Theme.primary

            // Click icon to toggle mute.
            MouseArea {
                anchors.fill: parent
                cursorShape:  Qt.PointingHandCursor
                onClicked:    if (card.audio) card.audio.muted = !card.audio.muted
            }
        }

        Slider {
            anchors.verticalCenter: parent.verticalCenter
            width:  170
            value:  card.volume
            onMoved: (v) => {
                if (!card.audio) return
                card.audio.volume = v
                if (card.audio.muted && v > 0) card.audio.muted = false
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text:           card.percent + "%"
            color:          Theme.fgSurface
            font.family:    Theme.monoFont
            font.pixelSize: 12
            width:          36
            horizontalAlignment: Text.AlignRight
        }
    }
}
