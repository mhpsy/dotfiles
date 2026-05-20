import QtQuick
import Quickshell.Io
import ".."

// Network pill — reads from NetworkData singleton. Shows the active iface's
// icon plus current down rate (so it's actually useful at a glance, matching
// waybar's bandwidth display). Hover → NetworkCard with IP + both directions.
Rectangle {
    id: root
    readonly property bool active: PopupState.networkOpen

    visible: NetworkData.connected
    radius:  Theme.radius
    color:   active ? Theme.primary : Theme.surfaceContainerHigh
    implicitWidth:  visible ? row.implicitWidth + 2 * Theme.pad : 0
    implicitHeight: Theme.barHeight - 8
    Behavior on color { ColorAnimation { duration: 200; easing.type: Easing.OutQuad } }

    readonly property string iconChar:
          NetworkData.ifaceType === "ethernet" ? ""
        : NetworkData.ifaceType !== "wifi"     ? ""
        : NetworkData.signalPct > 66           ? ""
        : NetworkData.signalPct > 33           ? ""
                                               : ""

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text:           root.iconChar
            font.family:    Theme.glyphFont
            font.styleName: Theme.glyphStyle
            font.pixelSize: 12
            color:          root.active ? Theme.fgPrimaryContainer : Theme.fgSurface
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            // Show download rate next to the icon — terse so it doesn't
            // dominate the bar. Full breakdown lives in the popup.
            text:           NetworkData.fmtBytes(NetworkData.rxRate)
            color:          root.active ? Theme.fgPrimaryContainer : Theme.fgSurfaceVariant
            font.family:    Theme.monoFont
            font.pixelSize: 11
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape:  Qt.PointingHandCursor
        onEntered: PopupState.openNetwork()
        onExited:  PopupState.closeNetwork()
        onClicked: launchProc.running = true
    }
    Process { id: launchProc; command: ["bash", "-c", "nm-connection-editor &"] }

    function reportAnchor() { PopupState.networkAnchorX = mapToItem(null, width / 2, 0).x }
    onXChanged:            reportAnchor()
    onWidthChanged:        reportAnchor()
    Component.onCompleted: reportAnchor()
}
