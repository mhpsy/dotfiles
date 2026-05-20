import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import "."

// Hover preview for a single workspace. The workspace identity is driven
// from PopupState.previewWorkspaceName (string), so the same popup blob
// can morph between workspaces as the user slides the pointer across pills.
Item {
    id: card
    implicitWidth:  300
    implicitHeight: col.implicitHeight + 24

    readonly property string wsName: PopupState.previewWorkspaceName
    readonly property var    wins:   HyprClientsData.clientsInWorkspace(wsName)

    readonly property string displayName: {
        if (wsName.indexOf("special:") === 0) {
            const tail = wsName.substring("special:".length)
            // Title-case the special name so "drawer" reads as "Drawer".
            return "特殊 · " + tail.charAt(0).toUpperCase() + tail.substring(1)
        }
        return "工作区 " + wsName
    }

    ColumnLayout {
        id: col
        anchors {
            left:    parent.left
            right:   parent.right
            top:     parent.top
            margins: 12
        }
        spacing: 6

        // ---- header ----
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text {
                Layout.fillWidth: true
                text:        card.displayName
                color:       Theme.fgSurface
                font.family: Theme.uiFont
                font.pixelSize: 13
                font.bold:   true
            }
            Text {
                text:           card.wins.length + " 个窗口"
                color:          Theme.fgSurfaceVariant
                font.family:    Theme.uiFont
                font.pixelSize: 11
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Theme.outline
            opacity: 0.2
        }

        // ---- empty state ----
        Text {
            Layout.fillWidth: true
            visible:        card.wins.length === 0
            text:           "（空，没有窗口）"
            color:          Theme.fgSurfaceVariant
            font.family:    Theme.uiFont
            font.pixelSize: 11
            font.italic:    true
            horizontalAlignment: Text.AlignHCenter
            Layout.topMargin:    4
            Layout.bottomMargin: 4
        }

        // ---- window rows ----
        Repeater {
            model: card.wins
            delegate: Rectangle {
                id: winRow
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                radius: 8
                color: Theme.surfaceContainerHigh

                // Robust app-icon lookup. Hyprland class names use underscores
                // (e.g. "adspower_global") while .desktop StartupWMClass often
                // uses spaces ("AdsPower Global") and icon-theme files use
                // hyphens ("adspower-global"). heuristicLookup helps but it's
                // not exhaustive — we try a chain of variants and pick the
                // first that resolves to a real DesktopEntry, falling back
                // to a hyphenated lower-case theme-icon guess.
                function _resolveEntry(cls) {
                    if (!cls) return null
                    const variants = [
                        cls,
                        cls.replace(/_/g, ' '),
                        cls.replace(/_/g, '-'),
                        cls.replace(/-/g, ' ')
                    ]
                    for (let i = 0; i < variants.length; i++) {
                        const e = DesktopEntries.heuristicLookup(variants[i])
                        if (e) return e
                    }
                    return null
                }
                readonly property var entry: _resolveEntry(modelData ? modelData.class : "")
                readonly property string iconUrl:
                      entry && entry.icon
                          ? "image://icon/" + entry.icon
                    : modelData && modelData.class
                          ? "image://icon/" + modelData.class.toLowerCase().replace(/_/g, '-')
                          : ""

                RowLayout {
                    anchors {
                        fill:        parent
                        leftMargin:  10
                        rightMargin: 10
                    }
                    spacing: 8
                    IconImage {
                        Layout.preferredWidth:  22
                        Layout.preferredHeight: 22
                        implicitSize: 22
                        source: winRow.iconUrl
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: -2
                        Text {
                            Layout.fillWidth: true
                            text:           modelData.title || "(无标题)"
                            color:          Theme.fgSurface
                            font.family:    Theme.uiFont
                            font.pixelSize: 12
                            elide:          Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            visible:        modelData.class && modelData.class.length > 0
                            text:           modelData.class || ""
                            color:          Theme.fgSurfaceVariant
                            font.family:    Theme.uiFont
                            font.pixelSize: 10
                            elide:          Text.ElideRight
                        }
                    }
                }
            }
        }
    }
}
