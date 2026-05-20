import QtQuick
import ".."

// Weather pill — reads from the WeatherData singleton and reports its hover
// state to PopupState. The actual popup card lives on a separate WlrLayershell
// owned by shell.qml; PopupState.weatherOpen is the shared open flag.
//
// Hover styling tracks PopupState (not the local MouseArea) so the pill stays
// "active" while the pointer is over the popup card too — the popup MouseArea
// keeps PopupState.weatherOpen true, which keeps the pill highlighted.
Rectangle {
    id: root
    readonly property bool active: PopupState.weatherOpen

    radius: Theme.radius
    color:  active ? Theme.primary : Theme.surfaceContainerHigh
    implicitWidth:  row.implicitWidth + 2 * Theme.pad
    implicitHeight: Theme.pillHeight

    Behavior on color { ColorAnimation { duration: 200; easing.type: Easing.OutQuad } }

    readonly property var cur: WeatherData.current || ({})

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text:           root.cur.icon || ""
            font.family:    Theme.glyphFont
            font.styleName: Theme.glyphStyle
            font.pixelSize: Theme.glyphSize
            color:          root.active ? Theme.fgPrimaryContainer : Theme.fgSurfaceVariant
            Behavior on color { ColorAnimation { duration: 200; easing.type: Easing.OutQuad } }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text:           (root.cur.temp || "--") + "°"
            font.family:    Theme.uiFont
            font.pixelSize: Theme.textSize
            color:          root.active ? Theme.fgPrimaryContainer : Theme.fgSurface
            Behavior on color { ColorAnimation { duration: 200; easing.type: Easing.OutQuad } }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape:  Qt.PointingHandCursor
        onEntered: PopupState.openWeather()
        onExited:  PopupState.closeWeather()
    }

    // Report pill screen-x to PopupState so the popup surface lands centered
    // on us. mapToItem(null, ...) maps to the root QML item; bar surface is
    // anchored left=0 on a full-width layer so root x == screen x.
    function reportAnchor() {
        PopupState.weatherAnchorX = mapToItem(null, width / 2, 0).x
    }
    onXChanged:     reportAnchor()
    onWidthChanged: reportAnchor()
    Component.onCompleted: reportAnchor()
}
