pragma Singleton
import QtQuick
import Quickshell

// Shared state for the bar's morphing popup blob.
//
// ONE popup surface in shell.qml hosts ONE clipped Item ("blob") that morphs
// between popups. This singleton drives that morph:
//
//   * `currentPopup` ("" / "weather" / "word" / "audio" / "brightness" / …)
//     selects which card is active.
//   * Per-popup geometry (anchor X / cardW / cardH) is reported externally
//     — pills report their own anchor via mapToItem(null,…); shell.qml
//     binds each card's implicitW/H back into PopupState.
//   * `current*` resolves to whichever source matches `currentPopup`.
//     openXxx() re-binds these with Qt.binding(...) atomically; the
//     Behaviors below animate the change — that IS the morph.
//   * `closeTimer.stop()` in every openXxx means moving the pointer
//     directly from one pill to another never visits state "" — the blob
//     stays open and slides sideways instead.
Singleton {
    id: root

    property string currentPopup: ""

    // --- per-popup sources (pills + cards write into these) ----------------
    property real weatherAnchorX:     0
    property real wordAnchorX:        0
    property real audioAnchorX:       0
    property real brightnessAnchorX:  0
    property real updatesAnchorX:     0
    property real bluetoothAnchorX:   0
    property real networkAnchorX:     0
    property real systemAnchorX:      0
    property real weatherCardW:       0
    property real wordCardW:          0
    property real audioCardW:         0
    property real brightnessCardW:    0
    property real updatesCardW:       0
    property real bluetoothCardW:     0
    property real networkCardW:       0
    property real systemCardW:        0
    property real weatherCardH:       0
    property real wordCardH:          0
    property real audioCardH:         0
    property real brightnessCardH:    0
    property real updatesCardH:       0
    property real bluetoothCardH:     0
    property real networkCardH:       0
    property real systemCardH:        0

    // --- resolved values the blob reads ------------------------------------
    property real currentAnchorX: 0
    property real currentCardW:   0
    property real currentCardH:   0

    // Gate on (currentPopup !== "") so the first open snaps geometry
    // instantly (no fly-in from 0,0). Subsequent open→open morphs animate.
    Behavior on currentAnchorX {
        enabled: root.currentPopup !== ""
        NumberAnimation { duration: 450; easing.bezierCurve: [0.38, 1.21, 0.22, 1, 1, 1] }
    }
    Behavior on currentCardW {
        enabled: root.currentPopup !== ""
        NumberAnimation { duration: 450; easing.bezierCurve: [0.38, 1.21, 0.22, 1, 1, 1] }
    }
    Behavior on currentCardH {
        enabled: root.currentPopup !== ""
        NumberAnimation { duration: 450; easing.bezierCurve: [0.38, 1.21, 0.22, 1, 1, 1] }
    }

    // --- module-side "is my popup active?" probes --------------------------
    readonly property bool weatherOpen:    currentPopup === "weather"
    readonly property bool wordOpen:       currentPopup === "word"
    readonly property bool audioOpen:      currentPopup === "audio"
    readonly property bool brightnessOpen: currentPopup === "brightness"
    readonly property bool updatesOpen:    currentPopup === "updates"
    readonly property bool bluetoothOpen:  currentPopup === "bluetooth"
    readonly property bool networkOpen:    currentPopup === "network"
    readonly property bool systemOpen:     currentPopup === "system"

    Timer {
        id: closeTimer
        interval: 200
        onTriggered: root.currentPopup = ""
    }

    function _open(name, anchor, w, h) {
        closeTimer.stop()
        root.currentAnchorX = Qt.binding(anchor)
        root.currentCardW   = Qt.binding(w)
        root.currentCardH   = Qt.binding(h)
        root.currentPopup   = name
    }

    function openWeather()    { _open("weather",    () => root.weatherAnchorX,    () => root.weatherCardW,    () => root.weatherCardH)    }
    function openWord()       { _open("word",       () => root.wordAnchorX,       () => root.wordCardW,       () => root.wordCardH)       }
    function openAudio()      { _open("audio",      () => root.audioAnchorX,      () => root.audioCardW,      () => root.audioCardH)      }
    function openBrightness() { _open("brightness", () => root.brightnessAnchorX, () => root.brightnessCardW, () => root.brightnessCardH) }
    function openUpdates()    { _open("updates",    () => root.updatesAnchorX,    () => root.updatesCardW,    () => root.updatesCardH)    }
    function openBluetooth()  { _open("bluetooth",  () => root.bluetoothAnchorX,  () => root.bluetoothCardW,  () => root.bluetoothCardH)  }
    function openNetwork()    { _open("network",    () => root.networkAnchorX,    () => root.networkCardW,    () => root.networkCardH)    }
    function openSystem()     { _open("system",     () => root.systemAnchorX,     () => root.systemCardW,     () => root.systemCardH)     }

    // Cancel the pending close — used by the blob's hover overlay so the
    // popup stays visible while the pointer is over its card.
    function keepOpen() { closeTimer.stop() }

    function close()           { closeTimer.restart() }
    // Per-name close aliases for symmetry — all schedule the same timer.
    function closeWeather()    { close() }
    function closeWord()       { close() }
    function closeAudio()      { close() }
    function closeBrightness() { close() }
    function closeUpdates()    { close() }
    function closeBluetooth()  { close() }
    function closeNetwork()    { close() }
    function closeSystem()     { close() }
}
