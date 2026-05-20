import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "."

Rectangle {
    id: card
    // Defaults to the shared WordData singleton; shell.qml can pass an
    // alternate instance for testing.
    property var words: WordData
    readonly property var cur: (words && words.current) ? words.current : ({})
    readonly property var todays: (words && words.today) ? words.today : []
    readonly property var curPos: (cur && cur.pos && cur.pos.length) ? cur.pos : []

    // shell.qml binds cardOpen to win.open; each false->true bumps introTick,
    // which the today-list rows watch to replay the staggered entrance cascade.
    property bool cardOpen: false
    property int introTick: 0
    onCardOpenChanged: if (cardOpen) introTick++

    implicitWidth: 460
    implicitHeight: col.implicitHeight
    radius: WordTheme.radius
    // No outer border / background — the metaball clipper in shell.qml owns
    // the popup background (Theme.surface) so the card reads as continuous
    // with the bar. The hero section still paints its own POS gradient.
    color: "transparent"
    clip: true

    Process {
        id: pickProc
        command: ["bash", "-c", "true"]   // command set per-click below
        // Refresh AFTER word-pick.sh exits (it has written the override by then),
        // so word-popup.sh reads the new state - deterministic ~30ms update, no
        // stale-flash race with the immediate-refresh approach.
        onExited: if (card.words) card.words.refresh()
    }
    Process { id: speakProc; command: ["bash", "-c", "~/.config/waybar/word-speak.sh"] }

    ColumnLayout {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top }
        spacing: 0

        // ============================ HERO ============================
        // Bold POS-driven gradient header (图#3). Colors come from the live
        // matugen palette via Theme, so it follows the desktop theme.
        Rectangle {
            id: hero
            Layout.fillWidth: true
            implicitHeight: heroCol.implicitHeight + 40
            topLeftRadius: WordTheme.radius
            topRightRadius: WordTheme.radius
            bottomLeftRadius: 0
            bottomRightRadius: 0
            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: WordTheme.heroA(card.curPos)
                    Behavior on color { ColorAnimation { duration: 320; easing.type: Easing.OutCubic } }
                }
                GradientStop {
                    position: 1.0
                    color: WordTheme.heroB(card.curPos)
                    Behavior on color { ColorAnimation { duration: 320; easing.type: Easing.OutCubic } }
                }
            }

            // faint POS "印记" motif, large, bleeding off the right edge
            Text {
                anchors { right: parent.right; rightMargin: 18; verticalCenter: parent.verticalCenter }
                text: WordTheme.posGlyph(card.curPos.length ? card.curPos[0] : "")
                font.family: WordTheme.glyphFont
                font.styleName: WordTheme.glyphStyle
                font.pixelSize: 132
                color: "#ffffff"
                opacity: 0.13
            }

            ColumnLayout {
                id: heroCol
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 22 }
                spacing: 4

                Text {
                    text: WordTheme.posLabelArr(card.curPos)
                    color: "#ffffff"
                    opacity: 0.6
                    font.family: WordTheme.uiFont
                    font.pixelSize: 11
                    font.bold: true
                    font.letterSpacing: 2
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Text {
                        text: card.cur.word || "--"
                        color: "#ffffff"
                        font.family: WordTheme.uiFont
                        font.pixelSize: 34
                        font.bold: true
                    }
                    Rectangle {
                        visible: card.curPos.length > 0
                        radius: 9
                        color: "#33ffffff"
                        implicitWidth: posChip.implicitWidth + 18
                        implicitHeight: posChip.implicitHeight + 8
                        Text {
                            id: posChip
                            anchors.centerIn: parent
                            text: card.curPos.join(" & ")
                            color: "#ffffff"
                            font.family: WordTheme.uiFont
                            font.pixelSize: 13
                            font.bold: true
                        }
                    }
                    Item { Layout.fillWidth: true }
                }

                Text {
                    text: card.cur.phonetic || ""
                    visible: text.length > 0
                    color: "#ffffff"
                    opacity: 0.72
                    font.family: WordTheme.uiFont
                    font.pixelSize: 13
                }

                Text {
                    text: card.cur.meaning || "--"
                    color: "#ffffff"
                    font.family: WordTheme.uiFont
                    font.pixelSize: 17
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    wrapMode: Text.WordWrap
                }

                RowLayout {
                    visible: (card.cur.example || "").length > 0
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    spacing: 9
                    Rectangle { implicitWidth: 3; Layout.fillHeight: true; radius: 2; color: "#80ffffff" }
                    Text {
                        text: card.cur.example || ""
                        color: "#ffffff"
                        opacity: 0.62
                        font.family: WordTheme.uiFont
                        font.pixelSize: 12
                        font.italic: true
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                    }
                }

                Rectangle {
                    id: speakBtn
                    Layout.topMargin: 8
                    implicitWidth: speakRow.implicitWidth + 28
                    implicitHeight: 32
                    radius: 10
                    color: speakMA.containsMouse ? "#4dffffff" : "#26ffffff"
                    Behavior on color { ColorAnimation { duration: 140 } }
                    RowLayout {
                        id: speakRow
                        anchors.centerIn: parent
                        spacing: 8
                        Text {
                            text: "\uf028"   // FA volume-high (Free Solid), ASCII-safe escape
                            font.family: WordTheme.glyphFont
                            font.styleName: WordTheme.glyphStyle
                            font.pixelSize: 13
                            color: "#ffffff"
                        }
                        Text {
                            text: "朗读单词"
                            color: "#ffffff"
                            font.family: WordTheme.uiFont
                            font.pixelSize: 13
                            font.bold: true
                        }
                    }
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
        }

        // ============================ FOOTER ==========================
        // Dark, compact 今日单词 list. Smaller than the hero (主体在上).
        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 18
            Layout.rightMargin: 18
            Layout.topMargin: 14
            Layout.bottomMargin: 16
            spacing: 7

            Text {
                text: "今日单词  ·  " + card.todays.length
                color: WordTheme.fgFaint
                font.family: WordTheme.uiFont
                font.pixelSize: 11
                font.letterSpacing: 1
            }

            Repeater {
                model: card.todays
                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool isCurrent: !!(card.cur && card.cur.word) && modelData.word === card.cur.word
                    Layout.fillWidth: true
                    implicitHeight: 30
                    radius: 9
                    color: rowMA.containsMouse ? WordTheme.chipBg : (row.isCurrent ? WordTheme.chipBg : "transparent")

                    // (A) staggered fade + slide-in entrance. Replays on EVERY open
                    // (card.introTick bumps when the card opens) so a pill click looks
                    // the same as a fresh launch; does NOT replay on word-pick (pick
                    // never toggles `open`; today-list identity ignores the current
                    // flag so the Repeater is not rebuilt).
                    //
                    // The 210ms lead-in is load-bearing: introTick fires on the SAME
                    // instant win.open->true, while the card-level opacity Behavior
                    // (200ms) + scale spring are still mid-transition. Without the
                    // lead the per-row stagger plays *under* that global card fade and
                    // is swamped into "just a fade". Holding the rows until the card
                    // is fully opaque makes the cascade read the same as the first-
                    // open/hot-reload case (where fetch latency happened to do this).
                    opacity: 0
                    transform: Translate { id: rowT; y: 24 }
                    function playIn() { row.opacity = 0; rowT.y = 24; rowInTimer.restart() }
                    Component.onCompleted: playIn()
                    Connections {
                        target: card
                        function onIntroTickChanged() { row.playIn() }
                    }
                    Timer {
                        id: rowInTimer
                        interval: 210 + row.index * 66
                        repeat: false
                        onTriggered: rowIn.start()
                    }
                    ParallelAnimation {
                        id: rowIn
                        NumberAnimation { target: row;  property: "opacity"; from: 0; to: 1; duration: 320; easing.type: Easing.OutCubic }
                        NumberAnimation { target: rowT; property: "y";       from: 24; to: 0; duration: 380; easing.type: Easing.OutCubic }
                    }

                    // (B) current-word glow pulse - two-part z:-1 Item so it never blocks
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
                            radius: 9
                            color: WordTheme.accent
                            opacity: 0.12 + 0.20 * glow.pulse
                        }
                        // bright accent border that thickens/brightens with the pulse
                        Rectangle {
                            anchors.fill: parent
                            radius: 9
                            color: "transparent"
                            border.color: WordTheme.accent
                            border.width: 2
                            opacity: 0.45 + 0.55 * glow.pulse
                        }
                    }

                    RowLayout {
                        anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                        spacing: 10
                        Text { text: row.modelData.word || "--"; color: row.isCurrent ? WordTheme.accent : WordTheme.fg; font.family: WordTheme.uiFont; font.pixelSize: 13; font.bold: row.isCurrent }
                        Text { text: row.modelData.meaning || ""; color: WordTheme.fgDim; font.family: WordTheme.uiFont; font.pixelSize: 11; Layout.fillWidth: true; horizontalAlignment: Text.AlignRight; elide: Text.ElideRight }
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
}
