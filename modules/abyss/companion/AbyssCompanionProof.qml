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
    title: bridge.backendEnabled
        ? "Wull procedural attachment proof [" + (bridge.ready ? bridge.visibility : "starting") + "]"
        : "Wull procedural attachment proof"

    CompanionBridge {
        id: bridge
    }

    Component.onCompleted: bridge.show()

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
        reveal: !bridge.backendEnabled ? 1
            : bridge.visibility === "present" ? 1
            : bridge.visibility === "peeking" ? 0.46 : 0
        gazeX: bridge.gazeX
        gazeY: bridge.gazeY
        energy: bridge.backendEnabled ? bridge.energy : 0.45
        bodySquash: bridge.squash
        bodyStretch: bridge.stretch
        bodyLean: bridge.lean
        bodyTip: bridge.tip
        ripple: bridge.ripple
        eyeOpen: bridge.eyeOpen
        mouthCurve: bridge.mouthCurve
        pulse: bridge.pulse

        onActivated: {
            pulse.restart()
            bridge.sendEvent("click")
        }
        onHoveredChanged: bridge.sendEvent("hover", hovered)
    }

    SequentialAnimation {
        id: pulse
        NumberAnimation { target: root; property: "opacity"; to: 0.94; duration: 70 }
        NumberAnimation { target: root; property: "opacity"; to: 1; duration: 160 }
    }
}
