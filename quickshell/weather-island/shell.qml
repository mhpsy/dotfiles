import QtQuick
import Quickshell
import Quickshell.Wayland

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

        Rectangle {
            id: box
            width: 220; height: 60
            radius: 16
            color: "#cc1020ff"
            Text {
                anchors.centerIn: parent
                text: "QS WEATHER OK"
                color: "white"; font.pixelSize: 18
            }
        }
    }
}
