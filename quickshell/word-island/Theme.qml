pragma Singleton
import QtQuick
import Quickshell

Singleton {
    readonly property string uiFont: "Fira Sans"
    readonly property string glyphFont: "Font Awesome 7 Free"
    readonly property string glyphStyle: "Solid"
    // colors are #AARRGGBB (QML/Qt ARGB order — alpha first)
    readonly property color cardBg1: "#f7101016"
    readonly property color cardBg2: "#f70a0a0e"
    readonly property color stroke:  "#22ffffff"
    readonly property color fg:      "#ffffff"
    readonly property color fgDim:   "#8cffffff"
    readonly property color fgFaint: "#73ffffff"
    readonly property color accent:  "#cdd6ff"
    readonly property color chipBg:  "#10ffffff"
    readonly property int radius: 18
    // POS → low-alpha background tint (#AARRGGBB). Unlisted POS → "transparent".
    readonly property var posTint: ({
        "n.":  "#3360a5fa",
        "v.":  "#33f0a050", "vt.": "#33f0a050", "vi.": "#33f0a050",
        "adj.":"#3340c0a0", "a.":  "#3340c0a0",
        "adv.":"#33a070e0", "ad.": "#33a070e0"
    })
    function tintFor(posArr) {
        var k = (posArr && posArr.length) ? posArr[0] : ""
        return posTint[k] || "transparent"
    }
}
