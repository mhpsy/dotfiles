import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import ".."

// System tray — SNI / StatusNotifierItem hosts.
//
// Interaction model:
//   left-click   → activate() unless onlyMenu, in which case show menu
//   middle-click → secondaryActivate()
//   right-click  → open native context menu (display())
//   scroll       → scroll(dx, dy)
//
// Menu is anchored to the icon's top-center in window coordinates; Qt's
// platform menu auto-flips above the anchor for bottom-of-screen bars.
//
// Requires shell.qml's `//@ pragma UseQApplication` (display() uses QMenu
// which only exists under QApplication, not QGuiApplication).
RowLayout {
    id: root
    spacing: 6

    Repeater {
        model: SystemTray.items

        delegate: MouseArea {
            id: trayBtn
            required property SystemTrayItem modelData

            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            Layout.preferredWidth:  Theme.barHeight - 14
            Layout.preferredHeight: Theme.barHeight - 14

            function showMenu() {
                const win = trayBtn.QsWindow.window
                const p = trayBtn.mapToItem(win.contentItem, trayBtn.width / 2, 0)
                modelData.display(win, p.x, p.y)
            }

            onClicked: (e) => {
                if (e.button === Qt.LeftButton) {
                    if (modelData.onlyMenu) showMenu()
                    else                    modelData.activate()
                } else if (e.button === Qt.MiddleButton) {
                    modelData.secondaryActivate()
                } else if (e.button === Qt.RightButton) {
                    showMenu()
                }
            }
            onWheel: (w) => modelData.scroll(w.angleDelta.x, w.angleDelta.y)

            IconImage {
                anchors.fill: parent
                source: trayBtn.modelData ? trayBtn.modelData.icon : ""
                // Explicit pixel size — parent.width is 0 at component
                // construction, which Quickshell's icon resolver caches as
                // QSize(2, 2) and warns about ever after. A constant kills
                // the warning and stops the "icon at 2x2" fallback storms
                // (e.g. Telegram's attention-symbolic icon).
                implicitSize: Theme.barHeight - 14
            }
        }
    }
}
