pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Shared Bluetooth state.
//
// `connectedDevices` is a list of { mac, name, battery } per connected
// device. Battery comes from `bluetoothctl info <mac>` — only present for
// devices that report it via the GATT Battery service (most modern
// headsets, mice, controllers; not all keyboards).
Singleton {
    id: root
    property bool powered: false
    property var  connectedDevices: []   // [{mac, name, battery: int|null}]

    readonly property int  connectedCount: connectedDevices.length
    readonly property var  singleDevice:   connectedCount === 1 ? connectedDevices[0] : null

    function refresh() { if (!proc.running) proc.running = true }

    // One bash invocation: list connected devices, dump info for each,
    // emit one CSV-ish line per device. Powered state on the last line.
    Process {
        id: proc
        // Defined in scripts/bluetooth-info.sh — kept out of QML because
        // template literals would interpret ${...} as JS substitutions.
        command: ["bash", Quickshell.env("HOME") + "/.config/quickshell/bar/scripts/bluetooth-info.sh"]
        stdout: StdioCollector {
            id: out
            waitForEnd: true
            onStreamFinished: {
                const lines = out.text.split('\n').filter((l) => l.length > 0)
                const devices = []
                for (const line of lines) {
                    if (line.startsWith("__POWER__ ")) {
                        root.powered = line.endsWith(" yes")
                        continue
                    }
                    const parts = line.split('|')
                    if (parts.length < 2) continue
                    const bat = parseInt(parts[2])
                    devices.push({
                        mac:     parts[0],
                        name:    parts[1],
                        battery: isNaN(bat) ? null : bat
                    })
                }
                root.connectedDevices = devices
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
    Component.onCompleted: root.refresh()
}
