// PRIVATE OFFSCREEN ONLY. Original Wull body/wrapper; real Qt animation clock.
// Controlled authored transitions are NOT a real Rust trace or a worst-case bound.
import QtQuick
import Quickshell
import qs.modules.abyss.companion

ShellRoot {
    id: root
    property string phase: "setup"
    property bool invalid: false
    property var records: []
    // PRIVATE per-phase snapshots; never serialize or publish coordinates.
    property var privateLastBounds: []
    readonly property var cases: {
        const rows = []
        for (const edge of ["top", "right", "bottom", "left"])
            for (const scaleValue of [0.65, 1.0, 1.5])
                rows.push({edge: edge, requested_scale: scaleValue,
                           index: rows.length})
        return rows
    }

    Item {
        id: stage
        width: 1700
        height: 1650
        Repeater {
            id: hosts
            model: root.cases
            delegate: AbyssCompanion {
                required property var modelData
                edge: modelData.edge
                scale: modelData.requested_scale
                x: 120 + (modelData.index % 3) * 460
                y: 120 + Math.floor(modelData.index / 3) * 360
                reveal: 1
                energy: 1
                interactive: false
                bodyStretch: 0
            }
        }
    }

    function bodyOf(host): var {
        const bodies = host.children.filter(child =>
            child.width === 76 && child.height === 92)
        return bodies.length === 1 ? bodies[0] : null
    }

    function bounds(host, body, spec): var {
        const corners = [
            body.mapToItem(host, 0, 0),
            body.mapToItem(host, body.width, 0),
            body.mapToItem(host, 0, body.height),
            body.mapToItem(host, body.width, body.height)
        ]
        const xs = corners.map(p => p.x)
        const ys = corners.map(p => p.y)
        const tip = body.mapToItem(host, body.width * 0.5, 2)
        const hostCorners = [
            host.mapToItem(stage, 0, 0),
            host.mapToItem(stage, host.width, 0),
            host.mapToItem(stage, 0, host.height),
            host.mapToItem(stage, host.width, host.height)
        ]
        const hx = hostCorners.map(p => p.x)
        const hy = hostCorners.map(p => p.y)
        const left = Math.min(...xs), right = Math.max(...xs)
        const top = Math.min(...ys), bottom = Math.max(...ys)
        const vertical = spec.edge === "right" || spec.edge === "left"
        const sx = vertical ? 3 : 18
        const sy = vertical ? 18 : 3
        const sw = vertical ? 92 : 76
        const sh = vertical ? 76 : 92
        const hostW = vertical ? 98 : 112
        const hostH = vertical ? 112 : 98
        const ew = Math.max(...hx) - Math.min(...hx)
        const eh = Math.max(...hy) - Math.min(...hy)
        const numbers = [left, right, top, bottom, tip.x, tip.y,
                         ew, eh, body.stateStretch, body.bob, body.sway]
        const eps = 0.12
        const consistent = numbers.every(Number.isFinite)
            && right > left && bottom > top
            && Math.abs(host.width - hostW) < 0.1
            && Math.abs(host.height - hostH) < 0.1
            && Math.abs(ew - hostW * spec.requested_scale) < 0.65
            && Math.abs(eh - hostH * spec.requested_scale) < 0.65
        return {
            consistent: consistent,
            left: left, right: right, top: top, bottom: bottom,
            stretch: body.stateStretch, bob: body.bob, sway: body.sway,
            bbox_outside_static: left < sx - eps || top < sy - eps
                || right > sx + sw + eps || bottom > sy + sh + eps,
            bbox_outside_host: left < -eps || top < -eps
                || right > hostW + eps || bottom > hostH + eps,
            tip_outside_static: tip.x < sx - eps || tip.y < sy - eps
                || tip.x > sx + sw + eps || tip.y > sy + sh + eps,
            tip_outside_host: tip.x < -eps || tip.y < -eps
                || tip.x > hostW + eps || tip.y > hostH + eps
        }
    }

    function newPhase(): var {
        return {
            samples: 0, active: true, stretch_witness: false,
            transition_witness: false, target_reached_witness: false,
            bob_witness: false, sway_witness: false,
            mapped_frame_change_witness: false,
            bbox_outside_static: false, bbox_outside_host: false,
            tip_outside_static: false, tip_outside_host: false,
            bbox_beyond_frozen: false
        }
    }

    function observe(): void {
        if (root.invalid) return
        for (let i = 0; i < root.cases.length; ++i) {
            const host = hosts.itemAt(i)
            const body = host ? root.bodyOf(host) : null
            if (!body || !root.records[i]) { root.invalid = true; return }
            const current = root.bounds(host, body, root.cases[i])
            const record = root.records[i]
            if (!current.consistent) { root.invalid = true; return }
            const sample = record[root.phase]
            sample.samples++
            const previous = root.privateLastBounds[i]
            if (previous) {
                const delta = Math.max(
                    Math.abs(current.left - previous.left),
                    Math.abs(current.right - previous.right),
                    Math.abs(current.top - previous.top),
                    Math.abs(current.bottom - previous.bottom))
                sample.mapped_frame_change_witness =
                    sample.mapped_frame_change_witness || delta > 0.12
            }
            root.privateLastBounds[i] = {
                left: current.left, right: current.right,
                top: current.top, bottom: current.bottom
            }
            sample.active = sample.active && body.motionEnabled === true
            sample.stretch_witness = sample.stretch_witness || (root.phase === "stretch"
                ? current.stretch > 0.2 : current.stretch < 0.8)
            // An instantaneous or failed transition must NOT earn a motion PASS.
            sample.transition_witness = sample.transition_witness
                || (current.stretch > 0.12 && current.stretch < 0.88)
            sample.target_reached_witness = sample.target_reached_witness
                || (root.phase === "stretch"
                    ? current.stretch > 0.85 : current.stretch < 0.15)
            sample.bob_witness = sample.bob_witness || Math.abs(current.bob) > 0.05
            sample.sway_witness = sample.sway_witness || Math.abs(current.sway) > 0.01
            for (const flag of ["bbox_outside_static", "bbox_outside_host",
                                "tip_outside_static", "tip_outside_host"])
                sample[flag] = sample[flag] || current[flag]
            const frozen = record.private_frozen
            sample.bbox_beyond_frozen = sample.bbox_beyond_frozen || current.left < frozen.left - 0.12
                || current.right > frozen.right + 0.12
                || current.top < frozen.top - 0.12
                || current.bottom > frozen.bottom + 0.12
        }
    }

    function emit(): void {
        if (root.invalid || root.records.length !== 12) {
            console.log("WULL_OFFSCREEN_DYNAMIC_INVALID")
            Qt.quit()
            return
        }
        const publicRows = root.records.map(r => ({
            edge: r.edge, requested_scale: r.requested_scale,
            neutral_verified: r.neutral_verified, frozen: r.frozen, stretch: r.stretch, release: r.release
        }))
        console.log("WULL_OFFSCREEN_DYNAMIC_GEOMETRY " + JSON.stringify(publicRows))
        Qt.quit()
    }

    Timer {
        interval: 1200
        running: true
        repeat: false
        onTriggered: {
            for (let i = 0; i < root.cases.length; ++i) {
                const host = hosts.itemAt(i)
                const body = host ? root.bodyOf(host) : null
                if (!body) { root.invalid = true; root.emit(); return }
                body.motionEnabled = false
                body.bob = 0
                body.sway = 0
                body.squash = 0
                body.stateSquash = 0
                body.stateLean = 0
                body.stateTip = 0
                body.stateStretch = 1
            }
            Qt.callLater(() => {
                for (let i = 0; i < root.cases.length; ++i) {
                    const host = hosts.itemAt(i)
                    const body = root.bodyOf(host)
                    const frozen = root.bounds(host, body, root.cases[i])
                    if (!frozen.consistent || body.motionEnabled !== false
                            || Math.abs(body.stateStretch - 1) > 0.0001
                            || Math.abs(body.bob) > 0.0001
                            || Math.abs(body.sway) > 0.0001
                            || Math.abs(body.stateSquash) > 0.0001
                            || Math.abs(body.stateLean) > 0.0001
                            || Math.abs(body.stateTip) > 0.0001) {
                        root.invalid = true
                        root.emit()
                        return
                    }
                    root.records.push({
                        edge: root.cases[i].edge,
                        requested_scale: root.cases[i].requested_scale,
                        neutral_verified: false,
                        private_frozen: frozen,
                        frozen: {
                            bbox_outside_static: frozen.bbox_outside_static,
                            bbox_outside_host: frozen.bbox_outside_host,
                            tip_outside_static: frozen.tip_outside_static,
                            tip_outside_host: frozen.tip_outside_host
                        },
                        stretch: root.newPhase(), release: root.newPhase()
                    })
                    body.stateStretch = 0
                }
                Qt.callLater(() => {
                    for (let i = 0; i < root.cases.length; ++i) {
                        const host = hosts.itemAt(i)
                        const body = root.bodyOf(host)
                        const neutral = root.bounds(host, body, root.cases[i])
                        if (!neutral.consistent || body.motionEnabled !== false
                                || Math.abs(body.stateStretch) > 0.0001
                                || neutral.bbox_outside_static
                                || neutral.bbox_outside_host
                                || neutral.tip_outside_static
                                || neutral.tip_outside_host) {
                            root.invalid = true
                            root.emit()
                            return
                        }
                        root.records[i].neutral_verified = true
                        body.motionEnabled = true
                        body.stateStretch = 1
                    }
                    root.privateLastBounds = []
                    root.phase = "stretch"
                    samples.start()
                    releasePhase.start()
                })
            })
        }
    }
    Timer {
        id: samples
        interval: 40
        running: false
        repeat: true
        onTriggered: root.observe()
    }
    Timer {
        id: releasePhase
        interval: 3200
        running: false
        repeat: false
        onTriggered: {
            for (let i = 0; i < root.cases.length; ++i)
                root.bodyOf(hosts.itemAt(i)).stateStretch = 0
            root.privateLastBounds = []
            root.phase = "release"
            finishPhase.start()
        }
    }
    Timer {
        id: finishPhase
        interval: 3200
        running: false
        repeat: false
        onTriggered: {
            samples.stop()
            root.emit()
        }
    }
    Timer {
        interval: 12000
        running: true
        repeat: false
        onTriggered: {
            console.log("WULL_OFFSCREEN_DYNAMIC_TIMEOUT")
            Qt.quit()
        }
    }
}
