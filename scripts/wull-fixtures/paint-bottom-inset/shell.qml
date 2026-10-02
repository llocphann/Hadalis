// PRIVATE exact original BOTTOM ×1.5 full companion cradle anchor inset.
// FOUR sequential original full-scene PNGs in ONE owned Qt offscreen session.
// Only disposable original cradle.anchors.bottomMargin is changed 0,1,2,3.
// NEVER alter original QML, native input Region, desktop, compositor or Git.
import QtQuick
import Quickshell
import qs.modules.abyss.companion

ShellRoot {
    id: root
    property bool started: false
    property bool finished: false
    property int index: 0
    property var pose: []
    property var sourceVisuals: []
    property var sourceCradle: null
    readonly property var margins: [0, 1, 2, 3]

    function stage(label): void {
        console.log("WULL_BOTTOM_INSET_STAGE=" + label)
    }
    function abort(reason): void {
        if (root.finished) return
        root.finished = true
        console.log("WULL_BOTTOM_INSET_FAILURE=" + reason)
        Qt.quit()
    }
    function body(): var {
        const items = host.children.filter(child =>
            child.width === 76 && child.height === 92)
        return items.length === 1 ? items[0] : null
    }
    function cradle(): var {
        const b = root.body()
        if (!b || host.children.length !== 2) return null
        const items = host.children.filter(child => child !== b)
        return items.length === 1 ? items[0] : null
    }
    function currentPose(): var {
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
        const values = []
        for (const p of points) values.push(p.x, p.y)
        return values.concat([
            b.stateStretch, b.bob, b.sway, b.rotation, host.scale,
            host.width, host.height, host.x, host.y, 2
        ])
    }
    function sourceAndPose(): bool {
        const b = root.body()
        const c = root.cradle()
        if (!b || !c || root.sourceCradle !== c ||
                host.children.length !== 2 ||
                b.children.length !== 5 ||
                root.sourceVisuals.length !== 5 ||
                !root.sourceVisuals.every(child =>
                    b.children.indexOf(child) >= 0 && child.visible) ||
                !b.visible || !c.visible ||
                c.width !== 58 || c.height !== 10 ||
                host.edge !== "bottom" || Math.abs(host.scale - 1.5) > .001 ||
                Math.abs(host.x - 100) > .01 ||
                Math.abs(host.y - 100) > .01 ||
                Math.abs(host.width - 112) > .01 ||
                Math.abs(host.height - 98) > .01 ||
                host.ripple !== 0 || host.pulse !== 0 ||
                b.motionEnabled || Math.abs(b.stateStretch - 1) > .001 ||
                Math.abs(b.rotation - 180) > .001 ||
                !privateWindow.backingWindowVisible ||
                Math.abs(stageItem.width - 320) > .01 ||
                Math.abs(stageItem.height - 300) > .01)
            return false
        const values = root.currentPose()
        if (values.length !== 24 || root.pose.length !== 24 ||
                !values.every((n, i) =>
                    Number.isFinite(n) &&
                    Math.abs(n - root.pose[i]) < .05))
            return false
        const h0 = host.mapToItem(stageItem, 0, 0)
        const h1 = host.mapToItem(stageItem, 112, 98)
        return Math.abs(h0.x - 72) < .15 &&
            Math.abs(h0.y - 75.5) < .15 &&
            Math.abs(h1.x - 240) < .15 &&
            Math.abs(h1.y - 222.5) < .15
    }
    function marginVerified(margin): bool {
        const c = root.sourceCradle
        if (!root.sourceAndPose() ||
                Math.abs(c.anchors.bottomMargin - margin) > .001)
            return false
        const a = c.mapToItem(stageItem, 0, 0)
        const b = c.mapToItem(stageItem, 58, 10)
        return [a.x, a.y, b.x, b.y].every(Number.isFinite) &&
            Math.abs(a.x - 112.5) < .18 &&
            Math.abs(a.y - (207.5 - 1.5 * margin)) < .18 &&
            Math.abs(b.x - 199.5) < .18 &&
            Math.abs(b.y - (222.5 - 1.5 * margin)) < .18
    }
    function path(margin): string {
        const directory = Quickshell.env("WULL_BOTTOM_INSET_DIR")
        if (!directory || directory.length < 10) return ""
        return directory + "/m" + margin + ".private.png"
    }
    function next(): void {
        if (root.finished) return
        if (root.index === root.margins.length) {
            root.sourceCradle.anchors.bottomMargin = 0
            Qt.callLater(() => {
                if (root.finished) return
                if (!root.marginVerified(0)) {
                    root.abort("ORIGINAL_MARGIN_RESTORE_FAILED")
                    return
                }
                root.stage("DONE")
                root.finished = true
                Qt.quit()
            })
            return
        }
        const margin = root.margins[root.index]
        if (!root.sourceAndPose()) {
            root.abort("ORIGINAL_SOURCE_OR_POSE_DRIFT")
            return
        }
        root.sourceCradle.anchors.bottomMargin = margin
        Qt.callLater(() => {
            if (root.finished) return
            if (!root.marginVerified(margin)) {
                root.abort("INSET_GEOMETRY_OR_SOURCE_INVALID")
                return
            }
            const output = root.path(margin)
            if (!output) {
                root.abort("PRIVATE_CAPTURE_PATH_INVALID")
                return
            }
            root.stage("M" + margin + "_REQUESTED")
            const started = stageItem.grabToImage(result => {
                if (root.finished) return
                if (!root.marginVerified(margin) || !result ||
                        !result.saveToFile(output)) {
                    root.abort("MARGIN_GRAB_OR_SAVE_FAILED")
                    return
                }
                root.stage("M" + margin + "_SAVED")
                root.index++
                Qt.callLater(() => root.next())
            }, Qt.size(320, 300))
            if (!started) root.abort("MARGIN_GRAB_UNAVAILABLE")
        })
    }
    function prepare(): void {
        if (root.started || root.finished) return
        root.started = true
        const b = root.body()
        const c = root.cradle()
        if (!b || !c || host.children.length !== 2 ||
                b.children.length !== 5 ||
                b.children.some(child => !child.visible) ||
                !c.visible || Math.abs(c.anchors.bottomMargin) > .001) {
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
            const core = b.children.filter(child =>
                child.width === 76 && child.height === 92 &&
                Math.abs(child.x) < .1 &&
                Math.abs(child.y) < .1)
            if (core.length !== 1 || c.width !== 58 ||
                    c.height !== 10 || !c.visible ||
                    b.children.some(child => !child.visible) ||
                    b.motionEnabled ||
                    Math.abs(b.stateStretch - 1) > .001 ||
                    Math.abs(b.bob) > .001 ||
                    Math.abs(b.sway) > .001 ||
                    Math.abs(b.rotation - 180) > .001) {
                root.abort("ORIGINAL_FROZEN_RENDERER_INVALID")
                return
            }
            root.sourceVisuals = b.children
            root.sourceCradle = c
            root.pose = root.currentPose()
            if (!root.marginVerified(0)) {
                root.abort("ORIGINAL_ZERO_MARGIN_POSE_INVALID")
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
        title: "Private original Wull bottom cradle inset pilot"
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
        onTriggered: root.abort("BOTTOM_INSET_TIMEOUT")
    }
}
