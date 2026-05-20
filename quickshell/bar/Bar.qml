import QtQuick
import QtQuick.Layouts
import "."
import "./modules"

// Bar root is a transparent Item that fills the layer-shell surface; the
// actual bar background is an inset Rectangle (`bg`) with horizontal
// barSideMargins, so the bar floats free from the screen edges. RowLayouts
// anchor to `bg` (not the root), and use Theme.barInnerPad so module
// content sits comfortably inside the rounded box.
//
// Layout follows waybar: workspaces CENTER, info modules LEFT, status /
// system modules RIGHT.
Item {
    id: root

    Rectangle {
        id: bg
        anchors {
            fill:        parent
            leftMargin:  Theme.barSideMargin
            rightMargin: Theme.barSideMargin
        }
        color:  Theme.surface
        radius: Theme.radius
    }

    // ---- LEFT: time + content modules ----
    RowLayout {
        anchors {
            left:           bg.left
            leftMargin:     Theme.barInnerPad
            verticalCenter: bg.verticalCenter
        }
        spacing: Theme.gap

        Clock {}
        DatePill {}
        SpecialButton { name: "drawer";        icon: ""; label: "DEV"  }
        SpecialButton { name: "chat";          icon: "";   label: "CHAT" }
        SpecialButton { name: "entertainment"; icon: "";    label: "DOCS" }
        Weather {}
        Quotes {}
        ActiveWindow { Layout.maximumWidth: 360 }
    }

    // ---- CENTER: workspaces ----
    RowLayout {
        anchors {
            horizontalCenter: bg.horizontalCenter
            verticalCenter:   bg.verticalCenter
        }
        spacing: Theme.gap

        Workspaces {}
    }

    // ---- RIGHT: status / system modules ----
    RowLayout {
        anchors {
            right:          bg.right
            rightMargin:    Theme.barInnerPad
            verticalCenter: bg.verticalCenter
        }
        spacing: Theme.gap

        Updates {}
        Reboot {}
        Caffeine {}
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
