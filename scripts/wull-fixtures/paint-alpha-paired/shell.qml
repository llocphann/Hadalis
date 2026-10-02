// PRIVATE FIXED-POSE SAME-QT-SESSION A/B. Original unmodified Wull QML.
// A = complete actual AbyssCompanion. B = same already-mapped companion
// with ONLY its original full-size four-cubic ShapePath child visible.
// B is an ALTERED PRIVATE visual state, NOT an exact production rendering.
// Captures ONLY our own 320x300 offscreen Item; no desktop/compositor.
import QtQuick
import Quickshell
import qs.modules.abyss.companion

ShellRoot {
    id: root
    property bool attempted: false
    property bool finished: false
    property var privatePose: []
    property var privateVisuals: []
    property var privateCore: null
    function stage(label): void {
        console.log("WULL_PAIRED_CORE_STAGE=" + label)
    }
    function abort(reason): void {
        if (root.finished) return
        root.finished = true
        console.log("WULL_PAIRED_CORE_FAILURE=" + reason)
        Qt.quit()
    }
    function pose(): var {
        const b = root.body()
        if (!b) return []
        const p0 = b.mapToItem(captureStage, 0, 0)
        const p1 = b.mapToItem(captureStage, 76, 0)
        const p2 = b.mapToItem(captureStage, 0, 92)
        const p3 = b.mapToItem(captureStage, 76, 92)
        const tip = b.mapToItem(captureStage, 38, 2)
        return [p0.x, p0.y, p1.x, p1.y, p2.x, p2.y,
                p3.x, p3.y, tip.x, tip.y, b.stateStretch,
                b.bob, b.sway, actualCompanion.x, actualCompanion.y,
                actualCompanion.width, actualCompanion.height,
                actualCompanion.scale, b.rotation]
    }
    function samePose(): bool {
        const fresh = root.pose()
        return fresh.length === root.privatePose.length
            && fresh.every((value, index) =>
                Number.isFinite(value)
                && Math.abs(value - root.privatePose[index]) < 0.05)
    }
    function body(): var {
        const bodies = actualCompanion.children.filter(child =>
            child.width === 76 && child.height === 92)
        return bodies.length === 1 ? bodies[0] : null
    }
    function startCore(output): void {
        if (root.finished || !root.samePose()) {
            root.abort("PAIRED_POSE_DRIFT")
            return
        }
        const visuals = root.privateVisuals
        const shape = root.privateCore
        if (visuals.length !== 5 || !shape || !shape.visible) {
            root.abort("CORE_ISOLATION_UNVERIFIED")
            return
        }
        for (const child of visuals) {
            if (child !== shape)
                child.visible = false
        }
        if (visuals.filter(child => child.visible).length !== 1) {
            root.abort("CORE_ISOLATION_UNVERIFIED")
            return
        }
        root.stage("CORE_ISOLATED")
        Qt.callLater(() => {
            if (root.finished) return
            if (!root.samePose() || !shape.visible
                    || visuals.filter(child => child.visible).length !== 1) {
                root.abort("CORE_POSE_OR_ISOLATION_DRIFT")
                return
            }
            root.stage("CORE_REQUESTED")
            const begun = captureStage.grabToImage(function(result) {
                if (root.finished) return
                if (!root.samePose() || !result
                        || !result.saveToFile(output)) {
                    root.abort("CORE_PNG_OR_POSE_FAILURE")
                    return
                }
                root.stage("CORE_SAVED")
                root.finished = true
                root.stage("FINISHED")
                Qt.quit()
            }, Qt.size(320, 300))
            if (!begun) root.abort("CORE_GRAB_UNAVAILABLE")
        })
    }

    FloatingWindow {
        id: privateWindow
        visible: false
        color: "transparent"
        Component.onCompleted: visible = true
        implicitWidth: 320
        implicitHeight: 300
        title: "Private Wull frozen-pose full/core paired alpha canary"
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
                ripple: 0
                pulse: 0
            }
        }
    }
    Component.onCompleted: root.stage("BOOT")
    Timer {
        interval: 1650
        running: true
        repeat: false
        onTriggered: {
            if (root.attempted || root.finished) return
            root.attempted = true
            const b = root.body()
            if (!privateWindow.backingWindowVisible || !b
                    || Math.abs(captureStage.width - 320) > 0.1
                    || Math.abs(captureStage.height - 300) > 0.1
                    || actualCompanion.width !== 112
                    || actualCompanion.height !== 98
                    || actualCompanion.scale !== 1
                    || actualCompanion.x !== 100
                    || actualCompanion.y !== 100) {
                root.abort("HOST_OR_BODY_UNVERIFIED")
                return
            }
            // Fix only this private instance's authored pose before BOTH
            // images. The actual production source QML is untouched.
            b.motionEnabled = false
            b.bob = 0
            b.sway = 0
            b.squash = 0
            b.stateSquash = 0
            b.stateStretch = 1
            b.stateLean = 0
            b.stateTip = 0
            b.shimmer = 0
            b.pulse = 0
            b.ripple = 0
            const visuals = b.children
            const coreCandidates = visuals.filter(child =>
                child.width === 76 && child.height === 92
                && Math.abs(child.x) < 0.1 && Math.abs(child.y) < 0.1)
            if (visuals.length !== 5 || coreCandidates.length !== 1
                    || visuals.some(child => !child.visible)
                    || b.motionEnabled || Math.abs(b.stateStretch - 1) > 0.001
                    || Math.abs(b.bob) > 0.001 || Math.abs(b.sway) > 0.001
                    || actualCompanion.ripple !== 0
                    || actualCompanion.pulse !== 0) {
                root.abort("PRIVATE_POSE_OR_VISUALS_INVALID")
                return
            }
            root.privateVisuals = visuals
            root.privateCore = coreCandidates[0]
            root.privatePose = root.pose()
            if (root.privatePose.length !== 19
                    || !root.samePose()) {
                root.abort("PRIVATE_POSE_GEOMETRY_INVALID")
                return
            }
            const fullOutput = Quickshell.env("WULL_CAPTURE_FULL")
            const coreOutput = Quickshell.env("WULL_CAPTURE_CORE")
            if (!fullOutput || !coreOutput || fullOutput === coreOutput
                    || fullOutput.length < 10 || coreOutput.length < 10) {
                root.abort("PRIVATE_OUTPUTS_INVALID")
                return
            }
            root.stage("SETUP_VERIFIED")
            Qt.callLater(() => {
                if (root.finished) return
                if (!root.samePose()
                        || visuals.some(child => !child.visible)) {
                    root.abort("PRE_FULL_POSE_DRIFT")
                    return
                }
                root.stage("COMPOSITE_REQUESTED")
                const begun = captureStage.grabToImage(function(result) {
                    if (root.finished) return
                    if (!root.samePose() || !result
                            || !result.saveToFile(fullOutput)) {
                        root.abort("COMPOSITE_PNG_OR_POSE_FAILURE")
                        return
                    }
                    root.stage("COMPOSITE_SAVED")
                    root.startCore(coreOutput)
                }, Qt.size(320, 300))
                if (!begun) root.abort("COMPOSITE_GRAB_UNAVAILABLE")
            })
        }
    }
    Timer {
        interval: 9500
        running: true
        repeat: false
        onTriggered: root.abort("CAPTURE_TIMEOUT")
    }
}
