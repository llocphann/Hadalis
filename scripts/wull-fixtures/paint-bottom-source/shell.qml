// PRIVATE: One ORIGINAL BOTTOM x1.5 at ONE frozen source-mapped pose.
// Capture FULL, CORE, BODY DETAILS and EXTERNAL CRADLE sequentially.
// Hidden siblings alter ONLY disposable original Qt instance. No compositor.
import QtQuick
import Quickshell
import qs.modules.abyss.companion

ShellRoot {
    id: root
    property bool started: false
    property bool finished: false
    property int captureIndex: 0
    property var originalPose: []
    property var bodyVisuals: []
    property var sourceCore: null
    property var sourceCradle: null
    readonly property var variants: ["full", "core", "details", "cradle"]

    function stage(label): void {
        console.log("WULL_BOTTOM_SOURCE_STAGE=" + label)
    }
    function abort(code): void {
        if (root.finished) return
        root.finished = true
        console.log("WULL_BOTTOM_SOURCE_FAILURE=" + code)
        Qt.quit()
    }
    function body(): var {
        const match = host.children.filter(c => c.width === 76 && c.height === 92)
        return match.length === 1 ? match[0] : null
    }
    function cradle(): var {
        const b = root.body()
        if (!b || host.children.length !== 2) return null
        const siblings = host.children.filter(c => c !== b)
        return siblings.length === 1 ? siblings[0] : null
    }
    function sourceConsistent(): bool {
        const b = root.body()
        const cradle = root.cradle()
        if (!b || !cradle || root.bodyVisuals.length !== 5 ||
                b.children.length !== 5 || root.sourceCore === null ||
                root.sourceCradle !== cradle ||
                !root.bodyVisuals.every(c => b.children.indexOf(c) >= 0) ||
                root.sourceCore.width !== 76 || root.sourceCore.height !== 92 ||
                Math.abs(root.sourceCore.x) > .1 ||
                Math.abs(root.sourceCore.y) > .1 ||
                Math.abs(cradle.width - 58) > .1 ||
                Math.abs(cradle.height - 10) > .1 ||
                host.edge !== "bottom" || Math.abs(host.scale - 1.5) > .001 ||
                Math.abs(host.width - 112) > .1 ||
                Math.abs(host.height - 98) > .1 ||
                Math.abs(host.x - 100) > .1 ||
                Math.abs(host.y - 100) > .1 ||
                !privateWindow.backingWindowVisible ||
                Math.abs(stageItem.width - 320) > .1 ||
                Math.abs(stageItem.height - 300) > .1)
            return false
        return true
    }
    function mappedPose(): var {
        const b = root.body()
        if (!b) return []
        const points = [
            b.mapToItem(stageItem, 0, 0),
            b.mapToItem(stageItem, 76, 0),
            b.mapToItem(stageItem, 0, 92),
            b.mapToItem(stageItem, 76, 92),
            b.mapToItem(stageItem, 38, 2),
            host.mapToItem(stageItem, 0, 0),
            host.mapToItem(stageItem, 112, 98)
        ]
        const numbers = []
        for (const p of points)
            numbers.push(p.x, p.y)
        return numbers.concat([
            b.stateStretch, b.bob, b.sway, b.rotation, host.scale,
            host.width, host.height, host.x, host.y,
            host.edge === "bottom" ? 2 : -1
        ])
    }
    function samePose(): bool {
        if (!root.sourceConsistent()) return false
        const values = root.mappedPose()
        if (values.length !== 24 || root.originalPose.length !== 24 ||
                !values.every((n, i) => Number.isFinite(n) &&
                    Math.abs(n - root.originalPose[i]) < .05))
            return false
        const topLeft = host.mapToItem(stageItem, 0, 0)
        const bottomRight = host.mapToItem(stageItem, 112, 98)
        return Math.abs(topLeft.x - 72) < .15 &&
            Math.abs(topLeft.y - 75.5) < .15 &&
            Math.abs(bottomRight.x - 240) < .15 &&
            Math.abs(bottomRight.y - 222.5) < .15
    }
    function scene(kind): bool {
        const visuals = root.bodyVisuals
        const core = root.sourceCore
        const cradle = root.sourceCradle
        if (visuals.length !== 5 || !core || !cradle ||
                root.cradle() !== cradle || !root.samePose())
            return false
        for (const child of visuals) child.visible = true
        cradle.visible = true
        if (kind === "core") {
            for (const child of visuals)
                if (child !== core) child.visible = false
            cradle.visible = false
        } else if (kind === "details") {
            core.visible = false
            cradle.visible = false
        } else if (kind === "cradle") {
            for (const child of visuals) child.visible = false
        } else if (kind !== "full") {
            return false
        }
        return root.sceneVerified(kind)
    }
    function sceneVerified(kind): bool {
        if (!root.samePose()) return false
        const visuals = root.bodyVisuals
        const core = root.sourceCore
        const cradle = root.sourceCradle
        if (kind === "full")
            return visuals.every(c => c.visible) && cradle.visible
        if (kind === "core")
            return core.visible && !cradle.visible &&
                visuals.filter(c => c.visible).length === 1
        if (kind === "details")
            return !core.visible && !cradle.visible &&
                visuals.filter(c => c.visible).length === 4
        if (kind === "cradle")
            return cradle.visible && visuals.every(c => !c.visible)
        return false
    }
    function path(kind): string {
        const directory = Quickshell.env("WULL_BOTTOM_SOURCE_DIR")
        if (!directory || directory.length < 10) return ""
        return directory + "/" + kind + ".private.png"
    }
    function next(): void {
        if (root.finished) return
        if (root.captureIndex === root.variants.length) {
            if (!root.scene("full") || !root.sceneVerified("full")) {
                root.abort("FINAL_ORIGINAL_SCENE_RESTORE_FAILED")
                return
            }
            root.stage("DONE")
            root.finished = true
            Qt.quit()
            return
        }
        const kind = root.variants[root.captureIndex]
        if (!root.scene(kind)) {
            root.abort("SOURCE_VISIBILITY_OR_POSE_CHANGED")
            return
        }
        Qt.callLater(() => {
            if (root.finished) return
            if (!root.sceneVerified(kind)) {
                root.abort("PRE_CAPTURE_SCENE_DRIFT")
                return
            }
            const path = root.path(kind)
            if (!path) { root.abort("PRIVATE_OUTPUT_UNAVAILABLE"); return }
            root.stage(kind.toUpperCase() + "_REQUESTED")
            const started = stageItem.grabToImage(result => {
                if (root.finished) return
                if (!root.sceneVerified(kind) || !result ||
                        !result.saveToFile(path)) {
                    root.abort("SCENE_GRAB_OR_SAVE_FAILED")
                    return
                }
                root.stage(kind.toUpperCase() + "_SAVED")
                root.captureIndex++
                Qt.callLater(() => root.next())
            }, Qt.size(320, 300))
            if (!started) root.abort("SCENE_GRAB_UNAVAILABLE")
        })
    }
    function prepare(): void {
        if (root.started || root.finished) return
        root.started = true
        const b = root.body()
        const cradle = root.cradle()
        if (!b || !cradle || b.children.length !== 5 ||
                b.children.some(c => !c.visible) || !cradle.visible) {
            root.abort("ORIGINAL_SOURCE_TOPOLOGY_INVALID")
            return
        }
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
        Qt.callLater(() => {
            if (root.finished) return
            const coreCandidates = b.children.filter(c =>
                c.width === 76 && c.height === 92 &&
                Math.abs(c.x) < .1 && Math.abs(c.y) < .1)
            if (coreCandidates.length !== 1 || b.motionEnabled ||
                    Math.abs(b.stateStretch - 1) > .001 ||
                    Math.abs(b.bob) > .001 || Math.abs(b.sway) > .001 ||
                    Math.abs(b.rotation - 180) > .001 ||
                    host.ripple !== 0 || host.pulse !== 0) {
                root.abort("FROZEN_SOURCE_STATE_INVALID")
                return
            }
            root.bodyVisuals = b.children
            root.sourceCore = coreCandidates[0]
            root.sourceCradle = cradle
            root.originalPose = root.mappedPose()
            if (!root.sourceConsistent() || !root.samePose() ||
                    !root.sceneVerified("full")) {
                root.abort("SOURCE_IDENTITY_OR_MAPPED_POSE_INVALID")
                return
            }
            root.stage("PREPARED")
            root.next()
        })
    }
    FloatingWindow {
        id: privateWindow
        visible: false
        color: "transparent"
        Component.onCompleted: visible = true
        implicitWidth: 320
        implicitHeight: 300
        title: "Private original Wull bottom source-paint isolation"
        Item {
            id: stageItem
            anchors.fill: parent
            AbyssCompanion {
                id: host
                edge: "bottom"
                scale: 1.5
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
        onTriggered: root.prepare()
    }
    Timer {
        interval: 24000
        running: true
        repeat: false
        onTriggered: root.abort("BOTTOM_SOURCE_TIMEOUT")
    }
}
