import QtQuick
import qs.modules.abyss.looks

// Development-only proof surface. This is deliberately not wired into the
// production shell until live attachment/hit-test evidence is collected.
Rectangle {
    id: root
    width: 520
    height: 260
    color: AbyssStyle.surfaceDeep

    Rectangle {
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        height: AbyssStyle.perimeterThickness
        color: AbyssStyle.surfaceRaised
    }

    AbyssCompanion {
        edge: "top"
        x: 210
        y: AbyssStyle.perimeterThickness - 5
        onActivated: pulse.restart()
    }

    SequentialAnimation {
        id: pulse
        NumberAnimation { target: root; property: "opacity"; to: 0.94; duration: 70 }
        NumberAnimation { target: root; property: "opacity"; to: 1; duration: 160 }
    }
}
