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
        implicitWidth: box.width
        implicitHeight: box.height
        layer: WlrLayer.Overlay
        keyboardFocus: WlrKeyboardFocus.None
        namespace: "qs-weather-island"

        WeatherData { id: wx }

        Rectangle {
            id: box
            width: 360; height: 70
            radius: 16
            color: "#cc101016"
            Text {
                anchors.centerIn: parent
                color: Theme.accent; font.pixelSize: 16
                text: wx.ok
                      ? (wx.city + "  " + (wx.current.temp || "--") + "°  " + (wx.current.desc || "")
                         + "  [h" + wx.hourly.length + " d" + wx.daily.length + "]")
                      : ("loading… " + wx.lastError)
            }
        }
    }
}
