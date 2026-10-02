// PRIVATE ONE-CASE CAPTURE FEASIBILITY ONLY. Never production or Niri.
// Actual unmodified AbyssCompanion and WaterDropletBody, fixed top/scale=1.
// This static frozen-pose snapshot does NOT witness dynamic movement.
// A full compositor screen is NEVER captured; only our own 320x300 Item.
import QtQuick
import Quickshell
import qs.modules.abyss.companion

ShellRoot {
    id: root
    property bool attempted: false
    property bool finished: false

    function status(name): void {
        console.log("WULL_PAINT_CANARY_STAGE=" + name)
    }
    function abort(category): void {
        if (root.finished) return
        root.finished = true
        console.log("WULL_PAINT_CANARY_FAILURE=" + category)
        Qt.quit()
    }

    FloatingWindow {
        id: privateWindow
        // Create with a transparent format BEFORE making the private window visible.
        visible: false
        color: "transparent"
        Component.onCompleted: visible = true
        implicitWidth: 320
        implicitHeight: 300
        title: "Private Wull paint capture canary"

        Item {
            id: captureStage
            anchors.fill: parent

            AbyssCompanion {
                id: actualCompanion
                edge: "top"
                scale: 1.0
                x: 100
                y: 100
                reveal: 1
                energy: 1
                interactive: false
                bodyStretch: 1
            }
        }
    }

    Component.onCompleted: root.status("BOOT")

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
                    || actualCompanion.width !== 112
                    || actualCompanion.height !== 98) {
                root.abort("WINDOW_OR_STAGE_INVALID")
                return
            }
            const body = actualCompanion.children.filter(child =>
                child.width === 76 && child.height === 92)
            if (body.length !== 1) {
                root.abort("ACTUAL_BODY_NOT_IDENTIFIED")
                return
            }
            // Freeze only this PRIVATE fixture instance; no production edits.
            body[0].motionEnabled = false
            body[0].bob = 0
            body[0].sway = 0
            body[0].stateStretch = 1
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
