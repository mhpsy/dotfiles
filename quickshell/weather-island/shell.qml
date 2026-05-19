import QtQuick
import Quickshell
import Quickshell.Wayland
import "."

ShellRoot {
    WlrLayershell {
        id: win
        anchors {
            top: true
            left: true
        }
        margins.left: 120
        margins.top: 0
        exclusiveZone: 0
        color: "transparent"
        implicitWidth: box.implicitWidth
        implicitHeight: box.implicitHeight
        layer: WlrLayer.Overlay
        keyboardFocus: WlrKeyboardFocus.None
        namespace: "qs-weather-island"

        WeatherData { id: wx }
        Column {
            id: box
            spacing: 8
            Pill { wx: wx.ok ? ({current: wx.current}) : null; }
            Card { wx: wx }
        }
    }
}
