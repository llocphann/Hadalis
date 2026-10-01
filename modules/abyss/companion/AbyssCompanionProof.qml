//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env INIR_STANDALONE_WINDOW=1

import QtQuick
import QtQuick.Controls
import QtQuick.Window
import Quickshell
import qs.modules.abyss.looks

// Development-only Quickshell proof surface. This is deliberately not wired
// into production shell ownership until live attachment/hit-test evidence is
// collected.
ApplicationWindow {
    id: root
    width: 520
    height: 260
    visible: true
    color: AbyssStyle.surfaceDeep
    title: "Wull procedural attachment proof"

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
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
