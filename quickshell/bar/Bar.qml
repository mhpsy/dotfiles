import QtQuick
import QtQuick.Layouts
import "."
import "./modules"

// Bar layout follows waybar: workspaces in the CENTER, info modules on the
// left, status / system modules on the right. We use three anchored
// RowLayouts (not one flex row with spacers) so the center group stays
// truly centered on the screen regardless of how wide left/right become.
Rectangle {
    id: root
    color: Theme.surface

    // ---- LEFT: time + content modules ----
    RowLayout {
        anchors {
            left:           parent.left
            leftMargin:     Theme.pad
            verticalCenter: parent.verticalCenter
        }
        spacing: Theme.gap

        Clock {}
        DatePill {}
        SpecialButton { name: "drawer";        icon: "" }
        SpecialButton { name: "chat";          icon: "" }
        SpecialButton { name: "entertainment"; icon: "" }
        Weather {}
        Quotes {}
        ActiveWindow { Layout.maximumWidth: 360 }
    }

    // ---- CENTER: workspaces ----
    RowLayout {
        anchors {
            horizontalCenter: parent.horizontalCenter
            verticalCenter:   parent.verticalCenter
        }
        spacing: Theme.gap

        Workspaces {}
    }

    // ---- RIGHT: status / system modules ----
    RowLayout {
        anchors {
            right:          parent.right
            rightMargin:    Theme.pad
            verticalCenter: parent.verticalCenter
        }
        spacing: Theme.gap

        Updates {}
        Reboot {}
        Brightness {}
        Audio {}
        Bluetooth {}
        Battery {}
        Network {}
        SystemMonitor {}
        Tray {}
        Notification {}
        Exit {}
    }
}
