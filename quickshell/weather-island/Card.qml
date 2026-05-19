import QtQuick
import QtQuick.Layouts
import "."

Rectangle {
    id: card
    property var wx
    readonly property var cur: (wx && wx.current) ? wx.current : ({})
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

    // ---- staggered entrance ------------------------------------------------
    // shell.qml binds cardOpen to win.open; each open bumps introTick which
    // restarts a single 0->1 driver. Sections derive opacity/offset from it
    // (revO/revY) with per-slot phase => hero -> grid -> hourly -> 3-day
    // cascade. The 200ms PauseAnimation lead clears the card-level opacity
    // (200ms) + scale spring so the cascade always plays on a fully-opaque
    // card (same lesson as word-island; never animate the Wayland surface).
    property bool cardOpen: false
    property int introTick: 0
    onCardOpenChanged: if (cardOpen) introTick++
    onIntroTickChanged: introPlay()
    property real intro: 0
    function revO(slot) { var t = (intro - slot * 0.18) / 0.46; return t < 0 ? 0 : (t > 1 ? 1 : t) }
    function revY(slot) { return (1 - revO(slot)) * 24 }
    function introPlay() { intro = 0; introAnim.restart() }
    Component.onCompleted: introPlay()
    SequentialAnimation {
        id: introAnim
        PauseAnimation { duration: 200 }
        NumberAnimation { target: card; property: "intro"; from: 0; to: 1; duration: 700; easing.type: Easing.OutCubic }
    }

    Ambient {
        anchors.fill: parent
        cond: (card.cur && card.cur.cond) ? card.cur.cond : "clouds"
        opacity: 0.9
        z: 0
        visible: card.visible
    }

    ColumnLayout {
        id: col
        z: 1  // keep content above Ambient (z:0)
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20 }
        spacing: 12

        // hero
        RowLayout {
            spacing: 16
            opacity: card.revO(0)
            transform: Translate { y: card.revY(0) }
            Text { text: card.cur.icon || ""; font.family: Theme.glyphFont; font.styleName: Theme.glyphStyle; font.pixelSize: 46; color: Theme.fg }
            ColumnLayout {
                spacing: 0
                Text { text: card.wx ? (card.wx.city || "--") : "--"; color: Theme.fgDim; font.family: Theme.uiFont; font.pixelSize: 12 }
                Text { text: (card.cur.temp || "--") + "°"; color: Theme.accent; font.family: Theme.uiFont; font.pixelSize: 42; font.bold: true }
                Text { text: card.cur.desc || "--"; color: Theme.accent; font.family: Theme.uiFont; font.pixelSize: 14 }
                Text { text: "体感 " + (card.cur.feel || "--") + "°C"; color: Theme.fgFaint; font.family: Theme.uiFont; font.pixelSize: 12 }
            }
            Item { Layout.fillWidth: true }
        }

        // 9-grid chips
        GridLayout {
            columns: 3
            rowSpacing: 8; columnSpacing: 8
            Layout.fillWidth: true
            opacity: card.revO(1)
            transform: Translate { y: card.revY(1) }
            Repeater {
                model: [
                    { k: "湿度",   v: (card.cur.humidity || "--") + "%" },
                    { k: "风 " + (card.cur.wind_dir || "--"), v: (card.cur.wind_speed || "--") + " km/h" },
                    { k: "气压",   v: (card.cur.pressure || "--") + " hPa" },
                    { k: "能见度", v: (card.cur.visibility || "--") + " km" },
                    { k: "风向",   v: (card.cur.wind_deg || "--") + "°" },
                    { k: "紫外线", v: "UV " + (card.cur.uv || "--") },
                    { k: "日出",   v: card.cur.sunrise || "--" },
                    { k: "日落",   v: card.cur.sunset || "--" },
                    { k: "降水",   v: (card.cur.pop || "--") + "% · " + (card.cur.precip || "--") + "mm" }
                ]
                delegate: Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 46
                    radius: 12
                    color: Theme.chipBg
                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Text { text: modelData.k; color: Theme.fgFaint; font.family: Theme.uiFont; font.pixelSize: 10; horizontalAlignment: Text.AlignHCenter; anchors.horizontalCenter: parent.horizontalCenter }
                        Text { text: modelData.v; color: Theme.fg; font.family: Theme.uiFont; font.pixelSize: 14; font.bold: true; horizontalAlignment: Text.AlignHCenter; anchors.horizontalCenter: parent.horizontalCenter }
                    }
                }
            }
        }

        Text {
            text: "逐时预报"; color: Theme.fgFaint; font.family: Theme.uiFont; font.pixelSize: 11
            opacity: card.revO(2)
            transform: Translate { y: card.revY(2) }
        }
        RowLayout {
            spacing: 7
            Layout.fillWidth: true
            opacity: card.revO(2)
            transform: Translate { y: card.revY(2) }
            Repeater {
                model: card.wx ? card.wx.hourly : []
                delegate: Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 64
                    radius: 12
                    color: Theme.chipBg
                    Column {
                        anchors.centerIn: parent; spacing: 3
                        Text { text: modelData.time || "--"; color: Theme.fgDim; font.family: Theme.uiFont; font.pixelSize: 10; anchors.horizontalCenter: parent.horizontalCenter }
                        Text { text: modelData.icon || ""; color: Theme.fg; font.family: Theme.glyphFont; font.styleName: Theme.glyphStyle; font.pixelSize: 17; anchors.horizontalCenter: parent.horizontalCenter }
                        Text { text: (modelData.temp || "--") + "°"; color: Theme.fg; font.family: Theme.uiFont; font.pixelSize: 13; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
                    }
                }
            }
        }

        Text {
            text: "未来三天"; color: Theme.fgFaint; font.family: Theme.uiFont; font.pixelSize: 11
            opacity: card.revO(3)
            transform: Translate { y: card.revY(3) }
        }
        Repeater {
            model: card.wx ? card.wx.daily : []
            delegate: Rectangle {
                Layout.fillWidth: true
                implicitHeight: 40
                radius: 12
                color: Theme.chipBg
                opacity: card.revO(3)
                transform: Translate { y: card.revY(3) }
                RowLayout {
                    anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                    spacing: 10
                    Text { text: modelData.icon || ""; color: Theme.fg; font.family: Theme.glyphFont; font.styleName: Theme.glyphStyle; font.pixelSize: 19 }
                    Text { text: modelData.label || "--"; color: Theme.fg; font.family: Theme.uiFont; font.pixelSize: 14 }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: (modelData.min || "--") + "° ~ " + (modelData.max || "--") + "°C  " + (modelData.desc || "")
                        color: Theme.fgDim; font.family: Theme.uiFont; font.pixelSize: 13
                    }
                }
            }
        }
    }
}
