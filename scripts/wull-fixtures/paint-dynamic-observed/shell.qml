// PRIVATE two-case actual-QML real spring dynamic FULL-composite painted pilot.
// TOP 1.0 and BOTTOM 1.5 only; no core isolation, no pixel causality claims.
// Independent 40ms private mapped-geometry + spring-state observer,
// while retaining the original 8 sequential real PNG grabs per phase/case.
// Fail closed if original state progresses but sampled motion is absent.
// Never screenshots of the desktop: grabToImage on own 320x300 private Items.
import QtQuick
import Quickshell
import qs.modules.abyss.companion

ShellRoot {
    id: root
    property bool finished: false
    property bool started: false
    property string phase: "setup"
    property int sampleIndex: 0
    property var lastGeometry: [null, null]
    property var moved: [false, false]
    property var stateMoved: [false, false]
    property var intermediateStretch: [false, false]
    property var observerTicks: [0, 0]
    property var lastSpringState: [0, 0]
    readonly property var specs: [
        { name: "top", edge: "top", scaleValue: 1.0 },
        { name: "bottom", edge: "bottom", scaleValue: 1.5 }
    ]
    function stage(token): void {
        console.log("WULL_DYNAMIC_PILOT_STAGE=" + token)
    }
    function abort(reason): void {
        if (root.finished) return
        root.finished = true
        console.log("WULL_DYNAMIC_PILOT_FAILURE=" + reason)
        Qt.quit()
    }
    function hostAt(n): var { return n === 0 ? topHost : bottomHost }
    function stageAt(n): var { return n === 0 ? topStage : bottomStage }
    function windowAt(n): var { return n === 0 ? topWindow : bottomWindow }
    function body(n): var {
        const host = root.hostAt(n)
        const list = host.children.filter(child =>
            child.width === 76 && child.height === 92)
        return list.length === 1 ? list[0] : null
    }
    function capturePath(n): string {
        const dir = Quickshell.env("WULL_DYNAMIC_PILOT_DIR")
        if (!dir || dir.length < 10) return ""
        return dir + "/" + root.phase + "-" + root.specs[n].name
               + "-" + root.sampleIndex + ".private.png"
    }
    function geometry(n): var {
        const host = root.hostAt(n)
        const stageItem = root.stageAt(n)
        const b = root.body(n)
        const spec = root.specs[n]
        if (!b || !root.windowAt(n).backingWindowVisible ||
                !b.motionEnabled || host.edge !== spec.edge ||
                Math.abs(host.scale - spec.scaleValue) > 0.0001 ||
                Math.abs(host.x - 100) > 0.01 ||
                Math.abs(host.y - 100) > 0.01 ||
                Math.abs(host.width - 112) > 0.01 ||
                Math.abs(host.height - 98) > 0.01 ||
                Math.abs(stageItem.width - 320) > 0.01 ||
                Math.abs(stageItem.height - 300) > 0.01 ||
                host.ripple !== 0 || host.pulse !== 0)
            return null
        const corners = [
            b.mapToItem(stageItem, 0, 0),
            b.mapToItem(stageItem, 76, 0),
            b.mapToItem(stageItem, 0, 92),
            b.mapToItem(stageItem, 76, 92)
        ]
        const values = []
        for (const p of corners) {
            values.push(p.x)
            values.push(p.y)
        }
        const h0 = host.mapToItem(stageItem, 0, 0)
        const h1 = host.mapToItem(stageItem, 112, 98)
        values.push(h0.x, h0.y, h1.x, h1.y)
        values.push(b.bob, b.sway, b.stateStretch)
        const scale = spec.scaleValue
        const left = 100 + 112 * (1 - scale) * 0.5
        const top = 100 + 98 * (1 - scale) * 0.5
        if (!values.every(Number.isFinite) ||
                Math.abs(h0.x - left) > 0.2 ||
                Math.abs(h0.y - top) > 0.2 ||
                Math.abs(h1.x - left - 112 * scale) > 0.2 ||
                Math.abs(h1.y - top - 98 * scale) > 0.2 ||
                Math.abs(b.stateStretch) > 2.0 ||
                Math.abs(b.bob) > 16 || Math.abs(b.sway) > 16)
            return null
        return values
    }
    function noteMotion(n, values): void {
        const prev = root.lastGeometry[n]
        if (prev && prev.length === values.length) {
            let diff = 0
            for (let i = 0; i < 8; i++)
                diff = Math.max(diff, Math.abs(prev[i] - values[i]))
            if (diff > 0.12) root.moved[n] = true
        }
        root.lastGeometry[n] = values
    }
    function watch(): void {
        if (root.finished || (root.phase !== "stretch"
                && root.phase !== "release")) return
        for (let n = 0; n < 2; n++) {
            const geometry = root.geometry(n)
            if (!geometry) {
                root.abort("OBSERVER_MAPPED_GEOMETRY_INVALID")
                return
            }
            root.noteMotion(n, geometry)
            const spring = geometry[geometry.length - 1]
            if (Math.abs(spring - root.lastSpringState[n]) > 0.10)
                root.stateMoved[n] = true
            if (spring > 0.12 && spring < 0.88)
                root.intermediateStretch[n] = true
            root.lastSpringState[n] = spring
            root.observerTicks[n]++
        }
    }
    function grab(n): void {
        if (root.finished) return
        const values = root.geometry(n)
        if (!values || root.phase === "setup") {
            root.abort("ACTIVE_SAMPLE_GEOMETRY_INVALID")
            return
        }
        root.noteMotion(n, values)
        const name = root.capturePath(n)
        if (!name) {
            root.abort("PRIVATE_CAPTURE_PATH_INVALID")
            return
        }
        const label = root.phase.toUpperCase() + "_" +
                      root.sampleIndex + "_" + root.specs[n].name.toUpperCase()
        const started = root.stageAt(n).grabToImage(function(result) {
            if (root.finished) return
            if (!result || !result.saveToFile(name) ||
                    !root.geometry(n)) {
                root.abort("SAMPLE_SAVE_OR_MOTION_FAILED")
                return
            }
            root.stage(label)
            if (n === 0) {
                // Sequential independent canvas exposures, not simultaneous.
                root.grab(1)
            } else {
                root.sampleIndex++
                if (root.sampleIndex === 8) {
                    root.finishPhase()
                } else {
                    tick.start()
                }
            }
        }, Qt.size(320, 300))
        if (!started) root.abort("SAMPLE_GRAB_UNAVAILABLE")
    }
    function finishPhase(): void {
        if (root.finished) return
        motionWatch.stop()
        // A saved PNG by itself does not establish real movement. Require
        // BOTH sampled mapped geometry and original spring-state witnesses
        // independently observed BEFORE completing EACH sampled phase.
        for (let n = 0; n < 2; n++) {
            const label = root.specs[n].name.toUpperCase() + "_"
                          + root.phase.toUpperCase()
            if (root.observerTicks[n] < 4) {
                root.abort("MOTION_" + label + "_OBSERVER_INSUFFICIENT")
                return
            }
            if (!root.stateMoved[n]) {
                root.abort("MOTION_" + label + "_SPRING_UNOBSERVED")
                return
            }
            if (!root.intermediateStretch[n]) {
                root.abort("MOTION_" + label + "_TRANSITION_UNOBSERVED")
                return
            }
            if (!root.moved[n]) {
                root.abort("MOTION_" + label + "_MAPPED_UNOBSERVED")
                return
            }
        }
        const top = root.body(0)
        const bottom = root.body(1)
        if (!top || !bottom) { root.abort("BODY_MISSING"); return }
        if (root.phase === "stretch") {
            if (top.stateStretch < 0.8 || bottom.stateStretch < 0.8) {
                root.abort("STRETCH_TARGET_NOT_OBSERVED")
                return
            }
            root.phase = "release"
            root.sampleIndex = 0
            root.moved = [false, false]
            root.stateMoved = [false, false]
            root.intermediateStretch = [false, false]
            root.observerTicks = [0, 0]
            root.lastSpringState = [top.stateStretch, bottom.stateStretch]
            root.lastGeometry = [root.geometry(0), root.geometry(1)]
            if (!root.lastGeometry[0] || !root.lastGeometry[1]) {
                root.abort("RELEASE_BASELINE_INVALID")
                return
            }
            top.stateStretch = 0
            bottom.stateStretch = 0
            root.stage("RELEASE_START")
            motionWatch.start()
            tick.start()
        } else {
            if (root.phase !== "release" ||
                    top.stateStretch > 0.2 ||
                    bottom.stateStretch > 0.2) {
                root.abort("RELEASE_TARGET_NOT_OBSERVED")
                return
            }
            root.stage("WITNESS_COMPLETE")
            root.finished = true
            root.stage("DONE")
            Qt.quit()
        }
    }
    function prepare(): void {
        if (root.started || root.finished) return
        root.started = true
        const a = root.body(0)
        const b = root.body(1)
        if (!a || !b || !topWindow.backingWindowVisible ||
                !bottomWindow.backingWindowVisible) {
            root.abort("PRIVATE_WINDOWS_NOT_READY")
            return
        }
        for (const droplet of [a, b]) {
            droplet.motionEnabled = false
            droplet.bob = 0
            droplet.sway = 0
            droplet.squash = 0
            droplet.stateSquash = 0
            droplet.stateLean = 0
            droplet.stateTip = 0
            droplet.stateStretch = 0
            droplet.ripple = 0
            droplet.pulse = 0
        }
        Qt.callLater(() => {
            if (root.finished) return
            if (a.motionEnabled || b.motionEnabled ||
                    Math.abs(a.stateStretch) > 0.001 ||
                    Math.abs(b.stateStretch) > 0.001) {
                root.abort("PRIVATE_NEUTRAL_STATE_UNVERIFIED")
                return
            }
            a.motionEnabled = true
            b.motionEnabled = true
            root.phase = "stretch"
            root.sampleIndex = 0
            root.lastGeometry = [root.geometry(0), root.geometry(1)]
            if (!root.lastGeometry[0] || !root.lastGeometry[1]) {
                root.abort("STRETCH_BASELINE_INVALID")
                return
            }
            root.moved = [false, false]
            root.stateMoved = [false, false]
            root.intermediateStretch = [false, false]
            root.observerTicks = [0, 0]
            root.lastSpringState = [a.stateStretch, b.stateStretch]
            root.stage("NEUTRAL_READY")
            a.stateStretch = 1
            b.stateStretch = 1
            root.stage("STRETCH_START")
            motionWatch.start()
            tick.start()
        })
    }

    FloatingWindow {
        id: topWindow
        visible: false
        color: "transparent"
        Component.onCompleted: visible = true
        implicitWidth: 320
        implicitHeight: 300
        title: "Private Wull active TOP sample"
        Item {
            id: topStage
            anchors.fill: parent
            AbyssCompanion {
                id: topHost
                edge: "top"
                scale: 1
                x: 100
                y: 100
                energy: 1
                reveal: 1
                interactive: false
                bodyStretch: 0
                ripple: 0
                pulse: 0
            }
        }
    }
    FloatingWindow {
        id: bottomWindow
        visible: false
        color: "transparent"
        Component.onCompleted: visible = true
        implicitWidth: 320
        implicitHeight: 300
        title: "Private Wull active BOTTOM sample"
        Item {
            id: bottomStage
            anchors.fill: parent
            AbyssCompanion {
                id: bottomHost
                edge: "bottom"
                scale: 1.5
                x: 100
                y: 100
                energy: 1
                reveal: 1
                interactive: false
                bodyStretch: 0
                ripple: 0
                pulse: 0
            }
        }
    }
    Component.onCompleted: root.stage("BOOT")
    Timer {
        interval: 1350
        repeat: false
        running: true
        onTriggered: root.prepare()
    }
    Timer {
        id: motionWatch
        interval: 40
        repeat: true
        running: false
        onTriggered: root.watch()
    }
    Timer {
        id: tick
        interval: 350
        repeat: false
        running: false
        onTriggered: root.grab(0)
    }
    Timer {
        interval: 38000
        repeat: false
        running: true
        onTriggered: root.abort("PILOT_TIMEOUT")
    }
}
