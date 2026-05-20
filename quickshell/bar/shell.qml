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
        exclusiveZone: Theme.barHeight
        keyboardFocus: WlrKeyboardFocus.None
        color:         "transparent"

        anchors {
            top:   true
            left:  true
            right: true
        }
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

        readonly property real fillet:    16
        readonly property real topCorner: Theme.radius + 2
        readonly property real maxH:      640

        anchors {
            top:   true
            left:  true
            right: true
        }
        margins.top:    Theme.barHeight
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
            x:      Math.max(0, PopupState.currentAnchorX - width / 2)
            width:  PopupState.currentCardW + 2 * popupSurface.fillet
            height: (PopupState.currentCardH + 16) * openness

            clip: true

            // ---- metaball outline (TOP-anchored variant) ----
            //
            // Walks clockwise from bottom-left of body. Top-left + top-right
            // are INVERSE fillets (Counterclockwise → arc center inside body
            // → bulges into body interior); bottom-left + bottom-right are
            // CONVEX corners. The strip y∈[0, fillet] spans full width and
            // glues against the bar above.
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                visible: blob.height > popupSurface.topCorner + popupSurface.fillet

                ShapePath {
                    strokeWidth: 0
                    fillColor:   Theme.surface

                    startX: popupSurface.fillet + popupSurface.topCorner
                    startY: blob.height

                    // bottom edge of body (left → right)
                    PathLine { x: blob.width - popupSurface.fillet - popupSurface.topCorner; y: blob.height }
                    // bottom-right convex
                    PathArc {
                        x: blob.width - popupSurface.fillet; y: blob.height - popupSurface.topCorner
                        radiusX: popupSurface.topCorner; radiusY: popupSurface.topCorner
                    }
                    // body right edge (going UP)
                    PathLine { x: blob.width - popupSurface.fillet; y: popupSurface.fillet }
                    // top-right INVERSE fillet (concave) — bulges into body
                    PathArc {
                        x: blob.width; y: 0
                        radiusX: popupSurface.fillet; radiusY: popupSurface.fillet
                        direction: PathArc.Counterclockwise
                    }
                    // top edge of strip (right → left)
                    PathLine { x: 0; y: 0 }
                    // top-left INVERSE fillet (concave) — symmetric
                    PathArc {
                        x: popupSurface.fillet; y: popupSurface.fillet
                        radiusX: popupSurface.fillet; radiusY: popupSurface.fillet
                        direction: PathArc.Counterclockwise
                    }
                    // body left edge (going DOWN)
                    PathLine { x: popupSurface.fillet; y: blob.height - popupSurface.topCorner }
                    // bottom-left convex — closes path
                    PathArc {
                        x: popupSurface.fillet + popupSurface.topCorner; y: blob.height
                        radiusX: popupSurface.topCorner; radiusY: popupSurface.topCorner
                    }
                }
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
                    popupSurface.fillet
                    - (implicitHeight + 5 + popupSurface.fillet) * (1 - blob.openness)
                opacity:                  PopupState.currentPopup === "weather" ? 1 : 0
                visible:                  opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 450; easing.bezierCurve: [0.38, 1.21, 0.22, 1, 1, 1] } }
            }

            WordCard {
                id: wordCard
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top:              parent.top
                anchors.topMargin:
                    popupSurface.fillet
                    - (implicitHeight + 5 + popupSurface.fillet) * (1 - blob.openness)
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
                    popupSurface.fillet
                    - (implicitHeight + 5 + popupSurface.fillet) * (1 - blob.openness)
                opacity:                  PopupState.currentPopup === "audio" ? 1 : 0
                visible:                  opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 450; easing.bezierCurve: [0.38, 1.21, 0.22, 1, 1, 1] } }
            }

            BrightnessCard {
                id: brightnessCard
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top:              parent.top
                anchors.topMargin:
                    popupSurface.fillet
                    - (implicitHeight + 5 + popupSurface.fillet) * (1 - blob.openness)
                opacity:                  PopupState.currentPopup === "brightness" ? 1 : 0
                visible:                  opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 450; easing.bezierCurve: [0.38, 1.21, 0.22, 1, 1, 1] } }
            }

            UpdatesCard {
                id: updatesCard
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top:              parent.top
                anchors.topMargin:
                    popupSurface.fillet
                    - (implicitHeight + 5 + popupSurface.fillet) * (1 - blob.openness)
                opacity:                  PopupState.currentPopup === "updates" ? 1 : 0
                visible:                  opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 450; easing.bezierCurve: [0.38, 1.21, 0.22, 1, 1, 1] } }
            }

            BluetoothCard {
                id: bluetoothCard
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top:              parent.top
                anchors.topMargin:
                    popupSurface.fillet
                    - (implicitHeight + 5 + popupSurface.fillet) * (1 - blob.openness)
                opacity:                  PopupState.currentPopup === "bluetooth" ? 1 : 0
                visible:                  opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 450; easing.bezierCurve: [0.38, 1.21, 0.22, 1, 1, 1] } }
            }

            NetworkCard {
                id: networkCard
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top:              parent.top
                anchors.topMargin:
                    popupSurface.fillet
                    - (implicitHeight + 5 + popupSurface.fillet) * (1 - blob.openness)
                opacity:                  PopupState.currentPopup === "network" ? 1 : 0
                visible:                  opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 450; easing.bezierCurve: [0.38, 1.21, 0.22, 1, 1, 1] } }
            }

            SystemCard {
                id: systemCard
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top:              parent.top
                anchors.topMargin:
                    popupSurface.fillet
                    - (implicitHeight + 5 + popupSurface.fillet) * (1 - blob.openness)
                opacity:                  PopupState.currentPopup === "system" ? 1 : 0
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
