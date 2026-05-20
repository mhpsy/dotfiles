import QtQuick
import Quickshell.Services.UPower
import ".."

// Battery pill — sources from UPower.displayDevice, the synthetic aggregate
// device UPower exposes. On desktops with no main battery the device exists
// but isPresent stays false; we hide the whole pill in that case so it doesn't
// leave a placeholder gap in the bar.
//
// UPower.percentage is 0..100 (not 0..1). State enum is UPowerDeviceState.
Rectangle {
    id: root
    readonly property var  dev:      UPower.displayDevice
    readonly property bool present:  dev && dev.isPresent
    readonly property int  percent:  present ? Math.round(dev.percentage) : 0
    readonly property bool charging: present
                                     && (dev.state === UPowerDeviceState.Charging
                                         || dev.state === UPowerDeviceState.FullyCharged)
    readonly property bool low:      present && !charging && percent < 20

    visible: present
    color:   Theme.surfaceContainerHigh
    radius:  Theme.radius
    implicitWidth:  visible ? (row.implicitWidth + 2 * Theme.pad) : 0
    implicitHeight: Theme.barHeight - 8

    readonly property string icon:
        !present    ? ""
      : charging    ? ""   // bolt
      : percent < 20 ? ""  // battery-empty
      : percent < 40 ? ""  // battery-quarter
      : percent < 60 ? ""  // battery-half
      : percent < 80 ? ""  // battery-three-quarters
                     : ""  // battery-full

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text:           root.icon
            font.family:    Theme.glyphFont
            font.styleName: Theme.glyphStyle
            font.pixelSize: 11
            color:          root.low ? Theme.error : Theme.fgSurfaceVariant
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text:           root.percent + "%"
            font.family:    Theme.uiFont
            font.pixelSize: 12
            color:          root.low ? Theme.error : Theme.fgSurface
        }
    }
}
