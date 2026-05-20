import QtQuick
import QtQuick.Layouts
import "."

// Weather popup card — material-you styled, sourced from WeatherData singleton.
//
// Self-contained: lays out city + big temp + condition + 4-stat chip row +
// 3-day forecast. A MouseArea covering the whole card keeps the popup open
// while the pointer is over it (paired with PopupState's debounced close).
Rectangle {
    id: card

    readonly property var cur: WeatherData.current || ({})

    implicitWidth:  380
    implicitHeight: col.implicitHeight + 32
    // Background is provided by the clipper in shell.qml (it owns the
    // bar-continuous Theme.surface fill). Card itself is transparent so the
    // morph reads as the bar literally growing upward.
    color: "transparent"

    // Hover detection now lives on the blob in shell.qml (single overlay
    // covers whichever card is active). No per-card MouseArea needed.

    ColumnLayout {
        id: col
        anchors {
            fill: parent
            margins: 16
        }
        spacing: 14

        // ---- header: condition glyph + city / temp / desc ----
        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            Text {
                text: card.cur.icon || ""
                font.family:    Theme.glyphFont
                font.styleName: Theme.glyphStyle
                font.pixelSize: 44
                color: Theme.primary
                Layout.alignment: Qt.AlignVCenter
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    text: WeatherData.city || "--"
                    color: Theme.fgSurfaceVariant
                    font.family: Theme.uiFont
                    font.pixelSize: 12
                }
                Text {
                    text: (card.cur.temp || "--") + "°"
                    color: Theme.primary
                    font.family: Theme.uiFont
                    font.pixelSize: 36
                    font.bold: true
                }
                Text {
                    text: card.cur.desc || "--"
                    color: Theme.fgSurface
                    font.family: Theme.uiFont
                    font.pixelSize: 13
                }
            }
        }

        // ---- stat chips ----
        Flow {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: [
                    { k: "体感", v: (card.cur.feel     || "--") + "°"            },
                    { k: "湿度", v: (card.cur.humidity || "--") + "%"            },
                    { k: "风",   v: (card.cur.wind_dir || "") + " "
                                  + (card.cur.wind_speed || "--") + "km/h"       },
                    { k: "气压", v: (card.cur.pressure || "--") + " hPa"         },
                    { k: "降水", v: (card.cur.pop      || "--") + "% "
                                  + (card.cur.precip   || "--") + "mm"            },
                    { k: "UV",   v: (card.cur.uv       || "--")                   }
                ]
                delegate: Rectangle {
                    required property var modelData
                    radius: 8
                    color: Theme.surfaceContainerHigh
                    implicitWidth:  chipText.implicitWidth + 14
                    implicitHeight: chipText.implicitHeight + 8
                    Text {
                        id: chipText
                        anchors.centerIn: parent
                        text: modelData.k + " " + modelData.v
                        font.family: Theme.uiFont
                        font.pixelSize: 11
                        color: Theme.fgSurfaceVariant
                    }
                }
            }
        }

        // ---- 3-day forecast ----
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Repeater {
                model: WeatherData.daily
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 78
                    radius: 12
                    color: Theme.surface
                    border.color: Theme.outline
                    border.width: 1

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 3
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: modelData.label || "--"
                            color: Theme.fgSurfaceVariant
                            font.family: Theme.uiFont
                            font.pixelSize: 11
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: modelData.icon || ""
                            font.family:    Theme.glyphFont
                            font.styleName: Theme.glyphStyle
                            font.pixelSize: 18
                            color: Theme.primary
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: (modelData.min || "--") + "° / "
                                  + (modelData.max || "--") + "°"
                            color: Theme.fgSurface
                            font.family: Theme.uiFont
                            font.pixelSize: 11
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: modelData.desc || ""
                            color: Theme.fgSurfaceVariant
                            font.family: Theme.uiFont
                            font.pixelSize: 10
                        }
                    }
                }
            }
        }

        // ---- footer: sunrise / sunset ----
        RowLayout {
            Layout.fillWidth: true
            spacing: 14
            Text {
                text: "日出 " + (card.cur.sunrise || "--")
                color: Theme.fgSurfaceVariant
                font.family: Theme.uiFont
                font.pixelSize: 11
            }
            Text {
                text: "日落 " + (card.cur.sunset  || "--")
                color: Theme.fgSurfaceVariant
                font.family: Theme.uiFont
                font.pixelSize: 11
            }
            Item { Layout.fillWidth: true }
        }
    }
}
