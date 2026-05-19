import QtQuick
import QtQuick.Particles
import "."

Item {
    id: amb
    property string cond: "clouds"
    anchors.fill: parent

    // clear: warm glow breathing
    Rectangle {
        anchors.fill: parent
        visible: amb.cond === "clear"
        radius: Theme.radius
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "#00ffc45a" }
            GradientStop { position: 1.0; color: "#33ffc45a" }
        }
        SequentialAnimation on opacity {
            running: amb.cond === "clear"; loops: Animation.Infinite
            NumberAnimation { from: 0.4; to: 1.0; duration: 2600; easing.type: Easing.InOutSine }
            NumberAnimation { from: 1.0; to: 0.4; duration: 2600; easing.type: Easing.InOutSine }
        }
    }

    // clouds/fog: drifting soft band
    Rectangle {
        id: drift
        visible: amb.cond === "clouds" || amb.cond === "fog"
        width: parent.width * 0.6; height: parent.height
        radius: Theme.radius
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "#00aab9e1" }
            GradientStop { position: 0.5; color: "#1faab9e1" }
            GradientStop { position: 1.0; color: "#00aab9e1" }
        }
        SequentialAnimation on x {
            running: drift.visible; loops: Animation.Infinite
            NumberAnimation { from: -drift.width; to: amb.width; duration: 12000; easing.type: Easing.Linear }
        }
    }

    // rain/thunder: diagonal falling particles
    // Note: glowdot.png (qrc:///particleresources/glowdot.png) is absent in this Qt6 build;
    // using ItemParticle with Rectangle delegate instead.
    // Note: z:-1 on Ambient does not hide ItemParticle delegates (they render above their parent z);
    // z:0 with source-order placement (before ColumnLayout) keeps particles behind col content.
    ParticleSystem {
        id: psys
        running: amb.cond === "rain" || amb.cond === "thunder"
        anchors.fill: parent
        ItemParticle {
            groups: ["d"]
            delegate: Rectangle {
                width: 2
                height: 14
                radius: 1
                color: "#cc96c8ff"
                opacity: 0.9
            }
        }
        Emitter {
            group: "d"
            enabled: psys.running
            anchors { top: parent.top; left: parent.left; right: parent.right }
            emitRate: 60
            lifeSpan: 1400
            velocity: AngleDirection { angle: 75; magnitude: 320; angleVariation: 5 }
        }
    }

    // snow: slow falling
    ParticleSystem {
        id: snow
        running: amb.cond === "snow"
        anchors.fill: parent
        ItemParticle {
            groups: ["s"]
            delegate: Rectangle {
                width: 6
                height: 6
                radius: 3
                color: "#eeffffff"
                opacity: 0.9
            }
        }
        Emitter {
            group: "s"; enabled: snow.running
            anchors { top: parent.top; left: parent.left; right: parent.right }
            emitRate: 26; lifeSpan: 6000
            velocity: AngleDirection { angle: 90; magnitude: 60; angleVariation: 12 }
        }
    }

    // thunder: occasional flash highlight
    Rectangle {
        anchors.fill: parent; radius: Theme.radius
        visible: amb.cond === "thunder"; color: "#b4c8ff"
        opacity: 0
        SequentialAnimation on opacity {
            running: amb.cond === "thunder"; loops: Animation.Infinite
            NumberAnimation { to: 0.0; duration: 3600 }
            NumberAnimation { to: 0.5; duration: 60 }
            NumberAnimation { to: 0.0; duration: 90 }
            NumberAnimation { to: 0.45; duration: 70 }
            NumberAnimation { to: 0.0; duration: 120 }
        }
    }
}
