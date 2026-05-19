import QtQuick
import QtQuick.Layouts
import Quickshell.Io
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

    Process {
        id: pickProc
        command: ["bash", "-c", "true"]   // command set per-click below
        // Refresh AFTER word-pick.sh exits (it has written the override by then),
        // so word-popup.sh reads the new state — deterministic ~30ms update, no
        // stale-flash race with the immediate-refresh approach.
        onExited: if (card.words) card.words.refresh()
    }
    Process { id: speakProc; command: ["bash", "-c", "~/.config/waybar/word-speak.sh"] }

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
                    color: speakMA.containsMouse ? Theme.stroke : Theme.chipBg
                    Text { anchors.centerIn: parent; text: ""; font.family: Theme.glyphFont; font.styleName: Theme.glyphStyle; font.pixelSize: 15; color: Theme.fg }
                    MouseArea {
                        id: speakMA
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            speakProc.running = false
                            speakProc.running = true
                        }
                    }
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
                required property int index
                readonly property bool isCurrent: !!(card.cur && card.cur.word) && modelData.word === card.cur.word
                Layout.fillWidth: true
                implicitHeight: 34
                radius: 10
                color: rowMA.containsMouse ? Theme.chipBg : (row.isCurrent ? Theme.chipBg : "transparent")

                // (A) staggered fade + slide-in entrance: each row starts 55ms after
                // the previous, after an 80ms lead-in. Fires once on delegate creation
                // (today-list identity ignores the current flag, so the Repeater does NOT
                // rebuild on pick → this does NOT replay on word-click).
                opacity: 0
                transform: Translate { id: rowT; y: 18 }
                Component.onCompleted: rowInTimer.start()
                Timer {
                    id: rowInTimer
                    interval: 80 + row.index * 55
                    repeat: false
                    onTriggered: rowIn.start()
                }
                ParallelAnimation {
                    id: rowIn
                    NumberAnimation { target: row;  property: "opacity"; from: 0; to: 1; duration: 300; easing.type: Easing.OutCubic }
                    NumberAnimation { target: rowT; property: "y";       from: 18; to: 0; duration: 360; easing.type: Easing.OutCubic }
                }

                // (B) current-word glow pulse — two-part z:-1 Item so it never blocks
                // rowMA. Gated on card.visible so it STOPS when the card is closed
                // (zero idle cost, mirrors Ambient gating).
                Item {
                    id: glow
                    z: -1
                    anchors.fill: parent
                    visible: row.isCurrent
                    property real pulse: 0.35
                    SequentialAnimation on pulse {
                        running: row.isCurrent && card.visible
                        loops: Animation.Infinite
                        onRunningChanged: if (!running) glow.pulse = 0.35
                        NumberAnimation { from: 0.35; to: 1.0; duration: 1100; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 1.0; to: 0.35; duration: 1100; easing.type: Easing.InOutSine }
                    }
                    // soft accent fill (low alpha so word/meaning stay readable on it)
                    Rectangle {
                        anchors.fill: parent
                        radius: 10
                        color: Theme.accent
                        opacity: 0.12 + 0.20 * glow.pulse      // ~0.12 .. ~0.32 — clearly visible breathing, text still legible
                    }
                    // bright accent border that thickens/brightens with the pulse
                    Rectangle {
                        anchors.fill: parent
                        radius: 10
                        color: "transparent"
                        border.color: Theme.accent
                        border.width: 3
                        opacity: 0.45 + 0.55 * glow.pulse      // ~0.45 .. ~1.0
                    }
                }

                RowLayout {
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    spacing: 10
                    Text { text: modelData.word || "--"; color: row.isCurrent ? Theme.accent : Theme.fg; font.family: Theme.uiFont; font.pixelSize: 14; font.bold: row.isCurrent }
                    Text { text: modelData.meaning || ""; color: Theme.fgDim; font.family: Theme.uiFont; font.pixelSize: 12; Layout.fillWidth: true; elide: Text.ElideRight }
                }
                MouseArea {
                    id: rowMA
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        pickProc.command = ["bash", "-c", "~/.config/waybar/word-pick.sh " + row.modelData.idx]
                        pickProc.running = false
                        pickProc.running = true
                    }
                }
            }
        }
    }
}
