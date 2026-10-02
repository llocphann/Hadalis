// PRIVATE SOURCE-PINNED STATIC 12-CASE PAIR MATRIX ONLY.
// ONE unmodified original AbyssCompanion; each case captures full composite
// before hiding only its four NON-core WaterDropletBody visual siblings.
// Same instance/pose per pair, but sequential frames NOT simultaneous.
// No screen, Niri, native backend, pointer, dynamic or production edits.
import QtQuick
import Quickshell
import qs.modules.abyss.companion

ShellRoot {
    id: root
    property bool started: false
    property bool finished: false
    property int caseIndex: 0
    property var privatePose: []
    property var privateVisuals: []
    property var privateCore: null
    readonly property var cases: {
        const out = []
        for (const edge of ["top", "right", "bottom", "left"])
            for (const scaleValue of [0.65, 1.0, 1.5])
                out.push({edge: edge, scaleValue: scaleValue})
        return out
    }
    function stage(name): void {
        // Only fixed case indices and enum stages, NEVER coordinates.
        console.log("WULL_STATIC_MATRIX_STAGE=" + name)
    }
    function abort(category): void {
        if (root.finished) return
        root.finished = true
        console.log("WULL_STATIC_MATRIX_FAILURE=" + category)
        Qt.quit()
    }
    function body(): var {
        const matches = host.children.filter(child =>
            child.width === 76 && child.height === 92)
        return matches.length === 1 ? matches[0] : null
    }
    function hostGeometryConsistent(): bool {
        const c = root.cases[root.caseIndex]
        if (!c || host.edge !== c.edge
                || Math.abs(host.scale - c.scaleValue) > 0.0001)
            return false
        const vertical = c.edge === "right" || c.edge === "left"
        const w = vertical ? 98 : 112
        const h = vertical ? 112 : 98
        if (Math.abs(host.width - w) > 0.1
                || Math.abs(host.height - h) > 0.1
                || Math.abs(host.x - 100) > 0.1
                || Math.abs(host.y - 100) > 0.1)
            return false
        const a = host.mapToItem(captureStage, 0, 0)
        const b = host.mapToItem(captureStage, w, h)
        const s = c.scaleValue
        const left = 100 + w * (1 - s) / 2
        const top = 100 + h * (1 - s) / 2
        return [a.x, a.y, b.x, b.y].every(Number.isFinite)
            && Math.abs(a.x - left) < 0.15
            && Math.abs(a.y - top) < 0.15
            && Math.abs(b.x - (left + w * s)) < 0.15
            && Math.abs(b.y - (top + h * s)) < 0.15
    }
    function mappedPose(): var {
        const b = root.body()
        if (!b) return []
        const points = [
            b.mapToItem(captureStage, 0, 0),
            b.mapToItem(captureStage, 76, 0),
            b.mapToItem(captureStage, 0, 92),
            b.mapToItem(captureStage, 76, 92),
            b.mapToItem(captureStage, 38, 2),
            host.mapToItem(captureStage, 0, 0),
            host.mapToItem(captureStage, host.width, host.height)
        ]
        const values = []
        for (const p of points) {
            values.push(p.x)
            values.push(p.y)
        }
        return values.concat([
            b.stateStretch, b.bob, b.sway, b.rotation,
            host.scale, host.width, host.height, host.x, host.y,
            root.cases.findIndex(spec => spec.edge === host.edge)
        ])
    }
    function samePose(): bool {
        const pose = root.mappedPose()
        return root.hostGeometryConsistent()
            && pose.length === root.privatePose.length
            && pose.every((value, i) => Number.isFinite(value)
                && Math.abs(value - root.privatePose[i]) < 0.05)
    }
    function path(kind): string {
        const directory = Quickshell.env("WULL_MATRIX_CAPTURE_DIR")
        if (!directory || directory.length < 10) return ""
        return directory + "/" + kind + "-" + root.caseIndex + ".private.png"
    }
    function captureCore(): void {
        if (root.finished || !root.samePose()) {
            root.abort("PAIR_POSE_DRIFT")
            return
        }
        const visuals = root.privateVisuals
        const core = root.privateCore
        if (visuals.length !== 5 || !core || !core.visible) {
            root.abort("CORE_IDENTITY_CHANGED")
            return
        }
        for (const child of visuals) {
            if (child !== core)
                child.visible = false
        }
        if (!core.visible || visuals.filter(child => child.visible).length !== 1) {
            root.abort("CORE_ISOLATION_FAILED")
            return
        }
        Qt.callLater(() => {
            if (root.finished) return
            if (!root.samePose() || !core.visible
                    || visuals.filter(child => child.visible).length !== 1) {
                root.abort("CORE_FRAME_POSE_DRIFT")
                return
            }
            const output = root.path("core")
            if (!output) { root.abort("PRIVATE_OUTPUT_INVALID"); return }
            root.stage("CASE_" + root.caseIndex + "_CORE_REQUESTED")
            const begun = captureStage.grabToImage(function(result) {
                if (root.finished) return
                if (!root.samePose() || !result
                        || !result.saveToFile(output)) {
                    root.abort("CORE_GRAB_OR_SAVE_FAILED")
                    return
                }
                root.stage("CASE_" + root.caseIndex + "_CORE_SAVED")
                for (const child of visuals)
                    child.visible = true
                root.caseIndex++
                // Never use a new process for subsequent edge/scale cases.
                Qt.callLater(() => root.startCase())
            }, Qt.size(320, 300))
            if (!begun) root.abort("CORE_GRAB_UNAVAILABLE")
        })
    }
    function startCase(): void {
        if (root.finished) return
        if (root.caseIndex === 12) {
            root.finished = true
            root.stage("DONE")
            Qt.quit()
            return
        }
        const c = root.cases[root.caseIndex]
        if (!c || root.caseIndex < 0 || root.caseIndex >= 12) {
            root.abort("CASE_INDEX_INVALID")
            return
        }
        host.edge = c.edge
        host.scale = c.scaleValue
        host.bodyStretch = 1
        host.ripple = 0
        host.pulse = 0
        root.stage("CASE_" + root.caseIndex + "_STARTED")
        Qt.callLater(() => {
            if (root.finished) return
            const b = root.body()
            if (!privateWindow.backingWindowVisible || !b
                    || Math.abs(captureStage.width - 320) > 0.1
                    || Math.abs(captureStage.height - 300) > 0.1
                    || !root.hostGeometryConsistent()) {
                root.abort("CASE_HOST_OR_BODY_INVALID")
                return
            }
            // Private authored freeze only: the original module QML is unchanged.
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
            const core = visuals.filter(child =>
                child.width === 76 && child.height === 92
                && Math.abs(child.x) < 0.1 && Math.abs(child.y) < 0.1)
            const edgeRotation = {
                "top": 0, "right": -90, "bottom": 180, "left": 90
            }[c.edge]
            if (visuals.length !== 5 || core.length !== 1
                    || visuals.some(child => !child.visible)
                    || b.motionEnabled || Math.abs(b.bob) > 0.0001
                    || Math.abs(b.sway) > 0.0001
                    || Math.abs(b.stateStretch - 1) > 0.0001
                    || Math.abs(b.rotation - edgeRotation) > 0.0001
                    || host.ripple !== 0 || host.pulse !== 0) {
                root.abort("CASE_SOURCE_POSE_OR_VISUALS_INVALID")
                return
            }
            root.privateVisuals = visuals
            root.privateCore = core[0]
            root.privatePose = root.mappedPose()
            if (root.privatePose.length !== 24 || !root.samePose()) {
                root.abort("CASE_MAPPED_GEOMETRY_INVALID")
                return
            }
            const output = root.path("full")
            if (!output) { root.abort("PRIVATE_OUTPUT_INVALID"); return }
            root.stage("CASE_" + root.caseIndex + "_FULL_REQUESTED")
            const begun = captureStage.grabToImage(function(result) {
                if (root.finished) return
                if (!root.samePose() || !result
                        || !result.saveToFile(output)) {
                    root.abort("FULL_GRAB_OR_SAVE_FAILED")
                    return
                }
                root.stage("CASE_" + root.caseIndex + "_FULL_SAVED")
                root.captureCore()
            }, Qt.size(320, 300))
            if (!begun) root.abort("FULL_GRAB_UNAVAILABLE")
        })
    }

    FloatingWindow {
        id: privateWindow
        visible: false
        color: "transparent"
        Component.onCompleted: visible = true
        implicitWidth: 320
        implicitHeight: 300
        title: "Private Wull static paired twelve-case matrix"
        Item {
            id: captureStage
            anchors.fill: parent
            AbyssCompanion {
                id: host
                edge: "top"
                scale: 1
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
        repeat: false
        running: true
        onTriggered: {
            if (!root.started && !root.finished) {
                root.started = true
                root.startCase()
            }
        }
    }
    Timer {
        interval: 65000
        repeat: false
        running: true
        onTriggered: root.abort("MATRIX_TIMEOUT")
    }
}
