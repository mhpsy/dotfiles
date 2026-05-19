pragma Singleton
import QtQuick
import Quickshell

Singleton {
    readonly property string uiFont: "Fira Sans"
    readonly property string glyphFont: "Symbols Nerd Font"
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
}
