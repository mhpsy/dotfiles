//@ pragma UseQApplication
// QApplication mode is required for SystemTrayItem.display() — that path
// uses Qt's platform-menu (QMenu) API which only exists under QApplication.
//
// TOP-anchored bar + a single morphing popup blob — quickshell-native
// replacement for waybar.
//
// Architecture:
//
//   * ONE bar surface (WlrLayershell, Top layer, TOP-anchored, full width,
//     fixed implicitHeight=Theme.barHeight). exclusionMode: Normal + an
//     exclusiveZone publishes the bar's footprint so client windows tile
//     below it.
//
//   * ONE popup surface (Overlay layer, TOP-anchored, full width, fixed
//     implicitHeight=maxH). All popups share this surface; inside lives a
//     `blob` Item whose x / width / height / content morph between popups
//     based on PopupState.currentPopup. mask follows blob's bbox, so
//     closed → bbox 0 → entire surface click-through.
//
//     Moving the pointer directly from one pill to another never visits
//     state="" (closeTimer is stopped by every openXxx), so the blob
//     slides + resizes smoothly between pills instead of close→open.
//
//   * implicitHeight on both surfaces is bound to constants — never to
//     content. Animating wlroots layer-surface size triggers per-frame
//     reconfigure + visible jitter.
//
//   * Inside the blob, `state` ("open"/"closed") follows currentPopup.
//     Transitions use different curves per direction:
//       open  → 500ms M3 expressive with overshoot (snappy emergence)
//       close → 160ms bezier with y₂>1 (pop-back bounce)
//     Qt auto-reverses partial transitions on state flips → mid-open
//     hover-out goes straight to snappy close from current value.
//
//   * Metaball outline (top-anchored variant): clipper is wider than the
//     body by `fillet` on each side. Strip (continuous-with-bar) sits at
//     the TOP of the clipper; body occupies the rest. The two L-notches
//     between strip and body are filled by CONCAVE arcs (Counterclockwise
//     PathArc → arc bulges into the body), so the popup looks like it's
//     flowing down out of the bar.
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import "."

ShellRoot {
    Binding {
        target:   WordData
        property: "active"
        value:    PopupState.wordOpen
    }

    // ---- bar surface (TOP) ----
    WlrLayershell {
        id: bar
        namespace:     "qs-bar"
        layer:         WlrLayer.Top
        exclusionMode: ExclusionMode.Normal
        // Reserve barHeight + (2*topMargin - gapsOut) so the gap below the
        // bar (= gapsOut applied past the reserved zone) ends up equal to
        // the gap above (= barTopMargin). Visual top/bottom symmetric float.
        exclusiveZone: Theme.barHeight + Math.max(0, 2 * Theme.barTopMargin - Theme.gapsOut)
        keyboardFocus: WlrKeyboardFocus.None
        color:         "transparent"

        anchors {
            top:   true
            left:  true
            right: true
        }
        margins.top:    Theme.barTopMargin
        implicitHeight: Theme.barHeight

        Bar { anchors.fill: parent }
    }

    // ---- single morphing popup surface (also TOP-anchored, below bar) ----
    WlrLayershell {
        id: popupSurface
        namespace:     "qs-bar-popup"
        layer:         WlrLayer.Overlay
        exclusionMode: ExclusionMode.Ignore
        keyboardFocus: WlrKeyboardFocus.None
        color:         "transparent"

        // Popup geometry. Top corners are flat (sit flush against the bar);
        // bottom corners are rounded. `pad` is the breathing room around
        // the card (both horizontal padding and the small gap at top).
        readonly property real pad:     12
        readonly property real bottomR: Theme.radius + 2
        readonly property real maxH:    640

        anchors {
            top:   true
            left:  true
            right: true
        }
        // Popup sits just below the floating bar. Match its top edge to
        // the bar's actual visual bottom (barTopMargin above + barHeight).
        margins.top:    Theme.barHeight + Theme.barTopMargin
        implicitHeight: maxH

        Binding { target: PopupState; property: "weatherCardW";    value: weatherCard.implicitWidth     }
        Binding { target: PopupState; property: "weatherCardH";    value: weatherCard.implicitHeight    }
        Binding { target: PopupState; property: "wordCardW";       value: wordCard.implicitWidth        }
        Binding { target: PopupState; property: "wordCardH";       value: wordCard.implicitHeight       }
        Binding { target: PopupState; property: "audioCardW";      value: audioCard.implicitWidth       }
        Binding { target: PopupState; property: "audioCardH";      value: audioCard.implicitHeight      }
        Binding { target: PopupState; property: "brightnessCardW"; value: brightnessCard.implicitWidth  }
        Binding { target: PopupState; property: "brightnessCardH"; value: brightnessCard.implicitHeight }
        Binding { target: PopupState; property: "updatesCardW";    value: updatesCard.implicitWidth     }
        Binding { target: PopupState; property: "updatesCardH";    value: updatesCard.implicitHeight    }
        Binding { target: PopupState; property: "bluetoothCardW";  value: bluetoothCard.implicitWidth   }
        Binding { target: PopupState; property: "bluetoothCardH";  value: bluetoothCard.implicitHeight  }
        Binding { target: PopupState; property: "networkCardW";    value: networkCard.implicitWidth     }
        Binding { target: PopupState; property: "networkCardH";    value: networkCard.implicitHeight    }
        Binding { target: PopupState; property: "systemCardW";     value: systemCard.implicitWidth      }
        Binding { target: PopupState; property: "systemCardH";     value: systemCard.implicitHeight     }
        Binding { target: PopupState; property: "caffeineCardW";   value: caffeineCard.implicitWidth    }
        Binding { target: PopupState; property: "caffeineCardH";   value: caffeineCard.implicitHeight   }
        Binding { target: PopupState; property: "workspaceCardW";  value: workspaceCard.implicitWidth   }
        Binding { target: PopupState; property: "workspaceCardH";  value: workspaceCard.implicitHeight  }
        Binding { target: PopupState; property: "clockCardW";      value: clockCard.implicitWidth       }
        Binding { target: PopupState; property: "clockCardH";      value: clockCard.implicitHeight      }
        Binding { target: PopupState; property: "dateCardW";       value: dateCard.implicitWidth        }
        Binding { target: PopupState; property: "dateCardH";       value: dateCard.implicitHeight       }

        mask: Region { item: blob }

        Item {
            id: blob

            property real openness: 0

            state: PopupState.currentPopup === "" ? "closed" : "open"
            states: [
                State { name: "open";   PropertyChanges { blob.openness: 1 } },
                State { name: "closed"; PropertyChanges { blob.openness: 0 } }
            ]
            transitions: [
                Transition {
                    to: "open"
                    NumberAnimation {
                        property: "openness"
                        duration: 500
                        easing.bezierCurve: [0.38, 1.21, 0.22, 1, 1, 1]
                    }
                },
                Transition {
                    to: "closed"
                    NumberAnimation {
                        property: "openness"
                        duration: 160
                        easing.bezierCurve: [0.3, 1.35, 0.35, 1, 1, 1]
                    }
                }
            ]

            anchors.top: parent.top
            // Try to center on the anchor pill; clamp to the bar's side
            // margin band so the popup never spills past the screen edge.
            x: {
                const desired = PopupState.currentAnchorX - width / 2
                const minX = Theme.barSideMargin
                const maxX = parent.width - width - Theme.barSideMargin
                return Math.max(minX, Math.min(maxX, desired))
            }
            width:  PopupState.currentCardW + 2 * popupSurface.pad
            height: (PopupState.currentCardH + 2 * popupSurface.pad) * openness

            clip: true

            // Bar-edge slab: top corners flat (flush against the bar),
            // bottom corners rounded. No metaball — every popup looks the
            // same regardless of which pill it's anchored to.
            Rectangle {
                anchors.fill: parent
                color:   Theme.surface
                topLeftRadius:     0
                topRightRadius:    0
                bottomLeftRadius:  popupSurface.bottomR
                bottomRightRadius: popupSurface.bottomR
            }

            // Card stack — both anchored to TOP of blob (popup grows down
            // from the bar), with topMargin sliding the card up out of
            // view when closed.
            //
            //   open  (offsetScale=0): topMargin = fillet  (rest position)
            //   close (offsetScale=1): topMargin = fillet - (cardH+5+fillet) = -cardH-5
            //                          → card pushed above clipper, fully clipped

            WeatherCard {
                id: weatherCard
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top:              parent.top
                anchors.topMargin:
                    popupSurface.pad
                    - (implicitHeight + 5 + popupSurface.pad) * (1 - blob.openness)
                opacity:                  PopupState.currentPopup === "weather" ? 1 : 0
                visible:                  opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 450; easing.bezierCurve: [0.38, 1.21, 0.22, 1, 1, 1] } }
            }

            WordCard {
                id: wordCard
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top:              parent.top
                anchors.topMargin:
                    popupSurface.pad
                    - (implicitHeight + 5 + popupSurface.pad) * (1 - blob.openness)
                cardOpen:                 PopupState.currentPopup === "word"
                opacity:                  PopupState.currentPopup === "word" ? 1 : 0
                visible:                  opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 450; easing.bezierCurve: [0.38, 1.21, 0.22, 1, 1, 1] } }
            }

            AudioCard {
                id: audioCard
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top:              parent.top
                anchors.topMargin:
                    popupSurface.pad
                    - (implicitHeight + 5 + popupSurface.pad) * (1 - blob.openness)
                opacity:                  PopupState.currentPopup === "audio" ? 1 : 0
                visible:                  opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 450; easing.bezierCurve: [0.38, 1.21, 0.22, 1, 1, 1] } }
            }

            BrightnessCard {
                id: brightnessCard
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top:              parent.top
                anchors.topMargin:
                    popupSurface.pad
                    - (implicitHeight + 5 + popupSurface.pad) * (1 - blob.openness)
                opacity:                  PopupState.currentPopup === "brightness" ? 1 : 0
                visible:                  opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 450; easing.bezierCurve: [0.38, 1.21, 0.22, 1, 1, 1] } }
            }

            UpdatesCard {
                id: updatesCard
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top:              parent.top
                anchors.topMargin:
                    popupSurface.pad
                    - (implicitHeight + 5 + popupSurface.pad) * (1 - blob.openness)
                opacity:                  PopupState.currentPopup === "updates" ? 1 : 0
                visible:                  opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 450; easing.bezierCurve: [0.38, 1.21, 0.22, 1, 1, 1] } }
            }

            BluetoothCard {
                id: bluetoothCard
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top:              parent.top
                anchors.topMargin:
                    popupSurface.pad
                    - (implicitHeight + 5 + popupSurface.pad) * (1 - blob.openness)
                opacity:                  PopupState.currentPopup === "bluetooth" ? 1 : 0
                visible:                  opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 450; easing.bezierCurve: [0.38, 1.21, 0.22, 1, 1, 1] } }
            }

            NetworkCard {
                id: networkCard
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top:              parent.top
                anchors.topMargin:
                    popupSurface.pad
                    - (implicitHeight + 5 + popupSurface.pad) * (1 - blob.openness)
                opacity:                  PopupState.currentPopup === "network" ? 1 : 0
                visible:                  opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 450; easing.bezierCurve: [0.38, 1.21, 0.22, 1, 1, 1] } }
            }

            SystemCard {
                id: systemCard
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top:              parent.top
                anchors.topMargin:
                    popupSurface.pad
                    - (implicitHeight + 5 + popupSurface.pad) * (1 - blob.openness)
                opacity:                  PopupState.currentPopup === "system" ? 1 : 0
                visible:                  opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 450; easing.bezierCurve: [0.38, 1.21, 0.22, 1, 1, 1] } }
            }

            CaffeineCard {
                id: caffeineCard
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top:              parent.top
                anchors.topMargin:
                    popupSurface.pad
                    - (implicitHeight + 5 + popupSurface.pad) * (1 - blob.openness)
                opacity:                  PopupState.currentPopup === "caffeine" ? 1 : 0
                visible:                  opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 450; easing.bezierCurve: [0.38, 1.21, 0.22, 1, 1, 1] } }
            }

            WorkspacePreviewCard {
                id: workspaceCard
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top:              parent.top
                anchors.topMargin:
                    popupSurface.pad
                    - (implicitHeight + 5 + popupSurface.pad) * (1 - blob.openness)
                opacity:                  PopupState.currentPopup === "workspace" ? 1 : 0
                visible:                  opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 450; easing.bezierCurve: [0.38, 1.21, 0.22, 1, 1, 1] } }
            }

            ClockCard {
                id: clockCard
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top:              parent.top
                anchors.topMargin:
                    popupSurface.pad
                    - (implicitHeight + 5 + popupSurface.pad) * (1 - blob.openness)
                opacity:                  PopupState.currentPopup === "clock" ? 1 : 0
                visible:                  opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 450; easing.bezierCurve: [0.38, 1.21, 0.22, 1, 1, 1] } }
            }

            DateCard {
                id: dateCard
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top:              parent.top
                anchors.topMargin:
                    popupSurface.pad
                    - (implicitHeight + 5 + popupSurface.pad) * (1 - blob.openness)
                opacity:                  PopupState.currentPopup === "date" ? 1 : 0
                visible:                  opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 450; easing.bezierCurve: [0.38, 1.21, 0.22, 1, 1, 1] } }
            }

            MouseArea {
                anchors.fill:    parent
                hoverEnabled:    true
                acceptedButtons: Qt.NoButton
                onEntered: PopupState.keepOpen()
                onExited:  PopupState.close()
            }
        }
    }
}
