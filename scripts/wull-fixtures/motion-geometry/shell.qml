// PRIVATE OFFSCREEN ONLY: actual unchanged AbyssCompanion/WaterDropletBody.
// Deliberately freeze continuous animation to isolate real Qt static vs
// source-permitted stretch=1 transform composition. Not an animated frame.
import QtQuick
import Quickshell
import qs.modules.abyss.companion

ShellRoot {
    id: root
    property var rows: []
    readonly property var cases: {
        const out = []
        const edges = ["top", "right", "bottom", "left"]
        const scales = [0.65, 1.0, 1.5]
        for (let ei = 0; ei < edges.length; ++ei)
            for (let si = 0; si < scales.length; ++si)
                out.push({edge: edges[ei], scale: scales[si],
                          row: ei, col: si})
        return out
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
                scale: modelData.scale
                x: 120 + modelData.col * 460
                y: 120 + modelData.row * 360
                reveal: 1
                interactive: true
                bodyStretch: 0
                energy: 0
            }
        }
    }

    function bodyOf(host): var {
        const eligible = host.children.filter(child =>
            child.width === 76 && child.height === 92)
        return eligible.length === 1 ? eligible[0] : null
    }

    function snapshot(host, spec, phase): var {
        const body = root.bodyOf(host)
        if (!body)
            return {valid: false}
        const corners = [
            body.mapToItem(host, 0, 0),
            body.mapToItem(host, body.width, 0),
            body.mapToItem(host, 0, body.height),
            body.mapToItem(host, body.width, body.height)
        ]
        const xs = corners.map(p => p.x), ys = corners.map(p => p.y)
        const left = Math.min(...xs), right = Math.max(...xs)
        const top = Math.min(...ys), bottom = Math.max(...ys)
        const vertical = spec.edge === "left" || spec.edge === "right"
        const bx = vertical ? 3 : 18
        const by = vertical ? 18 : 3
        const bw = vertical ? 92 : 76
        const bh = vertical ? 76 : 92
        const tip = body.mapToItem(host, body.width * 0.5, 2)
        const externalHost = [
            host.mapToItem(stage, 0, 0),
            host.mapToItem(stage, host.width, 0),
            host.mapToItem(stage, 0, host.height),
            host.mapToItem(stage, host.width, host.height)
        ]
        const eXs = externalHost.map(p => p.x)
        const eYs = externalHost.map(p => p.y)
        const eWidth = Math.max(...eXs) - Math.min(...eXs)
        const eHeight = Math.max(...eYs) - Math.min(...eYs)
        const values = [left, right, top, bottom, tip.x, tip.y,
                        eWidth, eHeight, host.width, host.height]
        const epsilon = 0.12
        return {
            valid: values.every(Number.isFinite) && right > left
                && bottom > top && eWidth > 0 && eHeight > 0,
            edge: spec.edge,
            requested_scale: spec.scale,
            phase: phase,
            host_width: host.width,
            host_height: host.height,
            stage_host_width: eWidth,
            stage_host_height: eHeight,
            bbox_left: left,
            bbox_top: top,
            bbox_right: right,
            bbox_bottom: bottom,
            tip_x: tip.x,
            tip_y: tip.y,
            bbox_inside_host: left >= -epsilon && top >= -epsilon
                && right <= host.width + epsilon
                && bottom <= host.height + epsilon,
            tip_inside_host: tip.x >= -epsilon && tip.y >= -epsilon
                && tip.x <= host.width + epsilon
                && tip.y <= host.height + epsilon,
            bbox_inside_source_static: left >= bx - epsilon
                && top >= by - epsilon
                && right <= bx + bw + epsilon
                && bottom <= by + bh + epsilon,
            tip_inside_source_static: tip.x >= bx - epsilon
                && tip.x <= bx + bw + epsilon
                && tip.y >= by - epsilon
                && tip.y <= by + bh + epsilon
        }
    }

    function collect(phase): bool {
        for (let index = 0; index < root.cases.length; ++index) {
            const host = hosts.itemAt(index)
            if (!host)
                return false
            const next = root.snapshot(host, root.cases[index], phase)
            if (!next.valid)
                return false
            root.rows.push(next)
        }
        return true
    }

    Timer {
        interval: 1250
        running: true
        repeat: false
        onTriggered: {
            for (let index = 0; index < root.cases.length; ++index) {
                const host = hosts.itemAt(index)
                const body = host ? root.bodyOf(host) : null
                if (!body) {
                    console.log("WULL_OFFSCREEN_MOTION_INVALID")
                    Qt.quit()
                    return
                }
                // Test-fixture overrides ONLY; original production source
                // remains unchanged. Freeze bob/sway/spring before sampling.
                body.motionEnabled = false
                body.bob = 0
                body.sway = 0
                body.squash = 0
                body.stateSquash = 0
                body.stateLean = 0
                body.stateTip = 0
                body.stateStretch = 0
            }
            Qt.callLater(() => {
                if (!root.collect("neutral")) {
                    console.log("WULL_OFFSCREEN_MOTION_INVALID")
                    Qt.quit()
                    return
                }
                for (let i = 0; i < root.cases.length; ++i)
                    root.bodyOf(hosts.itemAt(i)).stateStretch = 1
                stretched.start()
            })
        }
    }
    Timer {
        id: stretched
        interval: 1500
        running: false
        repeat: false
        onTriggered: {
            if (!root.collect("stretch_target")) {
                console.log("WULL_OFFSCREEN_MOTION_INVALID")
                Qt.quit()
                return
            }
            console.log("WULL_OFFSCREEN_MOTION_GEOMETRY " + JSON.stringify(root.rows))
            Qt.quit()
        }
    }
    Timer {
        interval: 9000
        running: true
        repeat: false
        onTriggered: {
            console.log("WULL_OFFSCREEN_MOTION_TIMEOUT")
            Qt.quit()
        }
    }
}
