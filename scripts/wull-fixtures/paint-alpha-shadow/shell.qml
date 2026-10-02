// PRIVATE STATIC TOP SCALE-1 SHADOW CANARY, NOT PRODUCTION COMPOSITE.
// Original UNMODIFIED WaterDropletBody, but WITHOUT AbyssCompanion cradle.
// No dynamic claim, native compositor, desktop or pointer input.
import QtQuick
import Quickshell
import qs.modules.abyss.companion

ShellRoot {
    id: root
    property bool attempted: false
    property bool finished: false

    function status(name): void {
        console.log("WULL_PAINT_SHADOW_STAGE=" + name)
    }
    function abort(category): void {
        if (root.finished) return
        root.finished = true
        console.log("WULL_PAINT_SHADOW_FAILURE=" + category)
        Qt.quit()
    }
    Component.onCompleted: root.status("BOOT")

    FloatingWindow {
        id: privateWindow
        visible: false
        color: "transparent"
        Component.onCompleted: visible = true
        implicitWidth: 320
        implicitHeight: 300
        title: "Private Wull body-only shadow canary"

        Item {
            id: captureStage
            anchors.fill: parent
            Item {
                id: shadowHost
                width: 112
                height: 98
                x: 100
                y: 100

                WaterDropletBody {
                    id: actualBody
                    width: 76
                    height: 92
                    anchors.centerIn: parent
                    transformOrigin: Item.Center
                    rotation: 0
                    energy: 1
                    enabled: false
                    visible: true
                    opacity: 1
                    motionEnabled: false
                    squash: 0
                    bob: 0
                    sway: 0
                    stateSquash: 0
                    stateStretch: 1
                    stateLean: 0
                    stateTip: 0
                    ripple: 0
                    pulse: 0
                }
            }
        }
    }

    Timer {
        interval: 1650
        running: true
        repeat: false
        onTriggered: {
            if (root.attempted || root.finished) return
            root.attempted = true
            if (!privateWindow.backingWindowVisible
                    || Math.abs(captureStage.width - 320) > 0.1
                    || Math.abs(captureStage.height - 300) > 0.1
                    || shadowHost.width !== 112
                    || shadowHost.height !== 98
                    || actualBody.width !== 76
                    || actualBody.height !== 92
                    || actualBody.parent !== shadowHost
                    || actualBody.motionEnabled !== false
                    || Math.abs(actualBody.stateStretch - 1) > 0.0001
                    || Math.abs(actualBody.rotation) > 0.0001
                    || Math.abs(actualBody.bob) > 0.0001
                    || Math.abs(actualBody.sway) > 0.0001
                    || actualBody.pulse !== 0
                    || actualBody.ripple !== 0) {
                root.abort("SHADOW_GEOMETRY_OR_STATE_INVALID")
                return
            }
            const output = Quickshell.env("WULL_CAPTURE_OUTPUT")
            if (!output || output.length < 10) {
                root.abort("PRIVATE_OUTPUT_NOT_SET")
                return
            }
            root.status("CAPTURE_REQUESTED")
            const begun = captureStage.grabToImage(function(result) {
                if (root.finished) return
                if (!result || !result.saveToFile(output)) {
                    root.abort("PNG_SAVE_FAILED")
                    return
                }
                root.finished = true
                root.status("PNG_SAVED")
                Qt.quit()
            }, Qt.size(320, 300))
            if (!begun) root.abort("GRAB_UNAVAILABLE")
        }
    }
    Timer {
        interval: 8000
        running: true
        repeat: false
        onTriggered: root.abort("CAPTURE_TIMEOUT")
    }
}
