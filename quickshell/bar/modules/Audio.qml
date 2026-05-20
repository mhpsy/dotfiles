import QtQuick
import Quickshell.Services.Pipewire
import ".."

// Default-sink volume + mute pill.
//
// Pipewire model: Pipewire.defaultAudioSink is a PipewireNode; its .audio is a
// PwNodeAudio with .volume (0..1) and .muted. Quickshell does NOT auto-track
// node lifetime — without a PwObjectTracker the node can be invalidated during
// graph rebuilds (sink change, profile switch). Track the node we read.
//
// Interactions: left-click toggles mute, scroll-wheel adjusts volume in 5%
// steps. Clamping is explicit because Pipewire accepts >1.0 boosts and we
// don't want surprise loudness.
Rectangle {
    id: root
    readonly property bool active: PopupState.audioOpen
    color:  active ? Theme.primary : Theme.surfaceContainerHigh
    radius: Theme.radius
    implicitWidth:  row.implicitWidth + 2 * Theme.pad
    implicitHeight: Theme.pillHeight
    Behavior on color { ColorAnimation { duration: 200; easing.type: Easing.OutQuad } }

    readonly property var  sink:     Pipewire.defaultAudioSink
    readonly property var  audio:    sink ? sink.audio : null
    readonly property bool muted:    audio ? audio.muted : false
    readonly property real volume:   audio ? audio.volume : 0
    readonly property int  percent:  Math.round(volume * 100)
    readonly property bool silenced: muted || percent === 0

    readonly property string icon:
        silenced       ? ""  // volume-xmark / mute
      : percent < 33   ? ""  // volume-low
      : percent < 66   ? ""
                       : ""  // volume-high

    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text:           root.icon
            font.family:    Theme.glyphFont
            font.styleName: Theme.glyphStyle
            font.pixelSize: Theme.glyphSize
            color:          root.silenced ? Theme.error : Theme.fgSurfaceVariant
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text:           root.percent + "%"
            font.family:    Theme.uiFont
            font.pixelSize: Theme.textSize
            color:          root.silenced ? Theme.error : Theme.fgSurface
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton
        onEntered: PopupState.openAudio()
        onExited:  PopupState.closeAudio()
        onClicked: {
            if (root.audio) root.audio.muted = !root.audio.muted
        }
        onWheel: (e) => {
            if (!root.audio) return
            const step = 0.05
            const next = root.audio.volume + (e.angleDelta.y > 0 ? step : -step)
            root.audio.volume = Math.max(0, Math.min(1, next))
            if (root.audio.muted && next > 0) root.audio.muted = false
        }
    }

    function reportAnchor() {
        PopupState.audioAnchorX = mapToItem(null, width / 2, 0).x
    }
    onXChanged:     reportAnchor()
    onWidthChanged: reportAnchor()
    Component.onCompleted: reportAnchor()
}
