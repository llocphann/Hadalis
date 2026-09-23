pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common
import qs.modules.common.functions

// Animated liquid ribbon for the Weather popup.
//
// This is intentionally not a collection of moving rounded rectangles. The
// Canvas rebuilds one continuous annulus every scene frame: the centreline
// drifts, both liquid boundaries carry travelling waves, hourly lobes breathe
// into the same contour, and specular streaks flow around the material. The
// labels/icons stay fixed above it so only the liquid moves.
Item {
    id: root

    property var hourAngles: []
    property real orbitRadiusX: 1
    property real orbitRadiusY: 1
    property real nodeWidth: 48
    property real nodeHeight: 58
    property int activeIndex: 0
    property bool animate: false

    readonly property int sampleCount: 96
    readonly property real baseThickness: Math.max(8,
        Math.min(12, Math.min(root.nodeWidth, root.nodeHeight) * 0.21))
    readonly property color bodyColor: ColorUtils.applyAlpha(
        ColorUtils.mix(
            Appearance.colors.colSurfaceContainerHigh,
            Appearance.colors.colPrimaryContainer,
            0.62),
        0.82)
    readonly property color bodyBright: ColorUtils.applyAlpha(
        ColorUtils.mix(
            Appearance.colors.colPrimaryContainer,
            Appearance.colors.colPrimary,
            0.78),
        0.62)
    readonly property color edgeColor: ColorUtils.applyAlpha(
        Appearance.colors.colPrimary, Appearance.effectsEnabled ? 0.72 : 0.52)
    readonly property color innerEdgeColor: ColorUtils.applyAlpha(
        Appearance.colors.colOnSurface, Appearance.effectsEnabled ? 0.15 : 0.08)
    readonly property color glowColor: ColorUtils.applyAlpha(
        Appearance.colors.colPrimary, Appearance.effectsEnabled ? 0.28 : 0.12)
    readonly property color glowTransparent: ColorUtils.applyAlpha(
        Appearance.colors.colPrimary, 0)
    readonly property color streakStrongColor: ColorUtils.applyAlpha(
        Appearance.colors.colOnPrimaryContainer, 0.28)
    readonly property color streakSoftColor: ColorUtils.applyAlpha(
        Appearance.colors.colOnPrimaryContainer, 0.17)
    readonly property bool ready: true

    // Animation follows the scene frame cadence. It is deliberately NOT gated
    // by effectsEnabled: disabling blur/shadows must not silently turn a liquid
    // design into a static shape. reduceAnimations still freezes it cleanly.
    FrameAnimation {
        id: liquidClock
        running: root.animate
            && root.visible
            && root.hourAngles.length > 0
            && Appearance.animationsEnabled
        onTriggered: liquidCanvas.requestPaint()
    }

    readonly property real timeSeconds: liquidClock.running
        ? liquidClock.elapsedTime
        : 0.73

    function wrapAngle(value: real): real {
        let wrapped = value % (Math.PI * 2)
        if (wrapped > Math.PI)
            wrapped -= Math.PI * 2
        else if (wrapped < -Math.PI)
            wrapped += Math.PI * 2
        return wrapped
    }

    function ellipseFrame(angle: real): var {
        const c = Math.cos(angle)
        const s = Math.sin(angle)
        const cx = root.width / 2 + c * root.orbitRadiusX
        const cy = root.height / 2 + s * root.orbitRadiusY

        // Unit tangent of the ellipse and its outward normal.
        const txRaw = -root.orbitRadiusX * s
        const tyRaw = root.orbitRadiusY * c
        const tLen = Math.max(0.001, Math.sqrt(txRaw * txRaw + tyRaw * tyRaw))
        const tx = txRaw / tLen
        const ty = tyRaw / tLen
        const nx = ty
        const ny = -tx
        return { cx, cy, tx, ty, nx, ny, speed: tLen }
    }

    function nodeInfluence(angle: real, nodeIndex: int, frame): var {
        if (nodeIndex < 0 || nodeIndex >= root.hourAngles.length)
            return { profile: 0, normalHalf: 0, signedArc: 0 }

        const nodeAngle = Number(root.hourAngles[nodeIndex] ?? 0)
        const nodeFrame = root.ellipseFrame(nodeAngle)
        const delta = root.wrapAngle(angle - nodeAngle)
        const signedArc = delta * nodeFrame.speed

        // Project the rectangular forecast footprint into local tangent/normal
        // axes. This makes top/side lobes keep comparable visual size.
        const tangentHalf = Math.max(18,
            0.5 * (Math.abs(nodeFrame.tx) * root.nodeWidth
                + Math.abs(nodeFrame.ty) * root.nodeHeight))
        const normalHalf = Math.max(root.baseThickness + 5,
            0.5 * (Math.abs(nodeFrame.nx) * root.nodeWidth
                + Math.abs(nodeFrame.ny) * root.nodeHeight))

        // Super-Gaussian shoulders give a metaball-like neck without a rigid
        // circular card edge. Tails overlap the ribbon instead of ending hard.
        const u = signedArc / Math.max(1, tangentHalf * 0.92)
        const profile = Math.exp(-Math.pow(Math.abs(u), 4.0))
        return { profile, normalHalf, signedArc }
    }

    function liquidSample(angle: real, time: real): var {
        const frame = root.ellipseFrame(angle)

        // Three incommensurate travelling waves keep the whole material moving
        // without an obvious short loop. They move the centreline itself, not
        // just the opacity or a child item.
        let normalDrift = Math.sin(angle * 3.0 - time * 1.15) * 2.6
            + Math.sin(angle * 5.0 + time * 0.73 + 1.1) * 1.35
            + Math.sin(angle * 2.0 - time * 0.31 + 2.4) * 0.85
        let tangentDrift = Math.sin(angle * 4.0 - time * 0.62 + 0.4) * 1.15
            + Math.sin(angle * 7.0 + time * 0.39) * 0.55
        let thickness = root.baseThickness
            + Math.sin(angle * 4.0 - time * 1.04) * 1.75
            + Math.sin(angle * 7.0 + time * 0.59 + 0.7) * 0.9

        // The hourly nodes are not separate shapes. Their influence fattens and
        // shears this same boundary, so the neck and the blob keep flowing as
        // one body. Each lobe breathes out of phase with its neighbours.
        for (let i = 0; i < root.hourAngles.length; ++i) {
            const influence = root.nodeInfluence(angle, i, frame)
            const active = i === root.activeIndex
            const breathe = Math.sin(time * (active ? 1.18 : 0.86)
                + i * 1.41 + Math.sin(time * 0.23 + i) * 0.45)
            const bumpTarget = influence.normalHalf - root.baseThickness
                + (active ? 7.0 : 1.5)
            thickness += influence.profile * Math.max(0, bumpTarget)
                * (1.0 + breathe * (active ? 0.085 : 0.055))

            // Opposite-signed shoulder shear makes the neck appear to pour
            // around the node instead of only breathing symmetrically.
            const shoulder = Math.tanh(influence.signedArc / 10.0)
            tangentDrift += influence.profile * shoulder
                * Math.sin(time * 0.74 + i * 0.93) * (active ? 3.8 : 2.1)
            normalDrift += influence.profile
                * Math.sin(time * 0.51 + i * 1.77) * (active ? 1.9 : 0.8)
        }

        const cx = frame.cx + frame.nx * normalDrift + frame.tx * tangentDrift
        const cy = frame.cy + frame.ny * normalDrift + frame.ty * tangentDrift
        return {
            cx, cy,
            outerX: cx + frame.nx * thickness,
            outerY: cy + frame.ny * thickness,
            innerX: cx - frame.nx * thickness,
            innerY: cy - frame.ny * thickness,
            tx: frame.tx, ty: frame.ty,
            nx: frame.nx, ny: frame.ny,
            thickness
        }
    }

    function traceClosed(ctx, points): void {
        if (!points || points.length < 3)
            return
        const count = points.length
        ctx.moveTo(points[0].x, points[0].y)
        for (let i = 0; i < count; ++i) {
            const p0 = points[(i + count - 1) % count]
            const p1 = points[i]
            const p2 = points[(i + 1) % count]
            const p3 = points[(i + 2) % count]
            ctx.bezierCurveTo(
                p1.x + (p2.x - p0.x) / 6,
                p1.y + (p2.y - p0.y) / 6,
                p2.x - (p3.x - p1.x) / 6,
                p2.y - (p3.y - p1.y) / 6,
                p2.x, p2.y)
        }
        ctx.closePath()
    }

    function traceOpen(ctx, points): void {
        if (!points || points.length < 2)
            return
        ctx.moveTo(points[0].x, points[0].y)
        for (let i = 0; i < points.length - 1; ++i) {
            const p0 = points[Math.max(0, i - 1)]
            const p1 = points[i]
            const p2 = points[i + 1]
            const p3 = points[Math.min(points.length - 1, i + 2)]
            ctx.bezierCurveTo(
                p1.x + (p2.x - p0.x) / 6,
                p1.y + (p2.y - p0.y) / 6,
                p2.x - (p3.x - p1.x) / 6,
                p2.y - (p3.y - p1.y) / 6,
                p2.x, p2.y)
        }
    }

    function requestPaint(): void {
        if (liquidCanvas.available)
            liquidCanvas.requestPaint()
    }

    onHourAnglesChanged: root.requestPaint()
    onOrbitRadiusXChanged: root.requestPaint()
    onOrbitRadiusYChanged: root.requestPaint()
    onNodeWidthChanged: root.requestPaint()
    onNodeHeightChanged: root.requestPaint()
    onActiveIndexChanged: root.requestPaint()
    onBodyColorChanged: root.requestPaint()
    onBodyBrightChanged: root.requestPaint()
    onEdgeColorChanged: root.requestPaint()

    Canvas {
        id: liquidCanvas
        anchors.fill: parent
        antialiasing: true
        renderStrategy: Canvas.Threaded
        renderTarget: Canvas.Image

        onAvailableChanged: if (available) requestPaint()
        onWidthChanged: if (available) requestPaint()
        onHeightChanged: if (available) requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            if (width <= 0 || height <= 0 || root.hourAngles.length === 0)
                return

            const time = root.timeSeconds
            const outer = []
            const inner = []
            for (let i = 0; i < root.sampleCount; ++i) {
                const angle = -Math.PI / 2 + i / root.sampleCount * Math.PI * 2
                const sample = root.liquidSample(angle, time)
                outer.push({ x: sample.outerX, y: sample.outerY })
                inner.push({ x: sample.innerX, y: sample.innerY })
            }

            // Active lobe gets a breathing radial halo. This is visual depth,
            // not the animation source; the silhouette itself is already moving.
            if (Appearance.effectsEnabled && root.activeIndex >= 0
                    && root.activeIndex < root.hourAngles.length) {
                const activeAngle = Number(root.hourAngles[root.activeIndex] ?? 0)
                const activeSample = root.liquidSample(activeAngle, time)
                const glowRadius = Math.max(root.nodeWidth, root.nodeHeight)
                    * (0.72 + 0.035 * Math.sin(time * 1.18))
                const glow = ctx.createRadialGradient(
                    activeSample.cx, activeSample.cy, 2,
                    activeSample.cx, activeSample.cy, glowRadius)
                glow.addColorStop(0, root.glowColor)
                glow.addColorStop(1, root.glowTransparent)
                ctx.fillStyle = glow
                ctx.beginPath()
                ctx.arc(activeSample.cx, activeSample.cy, glowRadius, 0, Math.PI * 2)
                ctx.fill()
            }

            // One continuous annulus. Reversing the inner subpath creates the
            // centre hole with the non-zero winding rule.
            const fillGradient = ctx.createLinearGradient(0, 0, width, height)
            fillGradient.addColorStop(0, root.bodyBright)
            fillGradient.addColorStop(0.48, root.bodyColor)
            fillGradient.addColorStop(1, root.bodyBright)
            ctx.fillStyle = fillGradient
            ctx.beginPath()
            root.traceClosed(ctx, outer)
            root.traceClosed(ctx, inner.slice().reverse())
            ctx.fill()

            // Outer/inner rims move with the boundaries and make deformation
            // readable over both light and dark popup backdrops.
            ctx.lineWidth = 1.35
            ctx.strokeStyle = root.edgeColor
            ctx.beginPath()
            root.traceClosed(ctx, outer)
            ctx.stroke()
            ctx.lineWidth = 0.9
            ctx.strokeStyle = root.innerEdgeColor
            ctx.beginPath()
            root.traceClosed(ctx, inner)
            ctx.stroke()

            // Three travelling specular streaks visibly flow around the liquid.
            // They follow the deformed surface, so this cannot read as a static
            // liquid-shaped plate with an opacity animation on top.
            if (Appearance.effectsEnabled) {
                for (let streak = 0; streak < 3; ++streak) {
                    const centerAngle = -Math.PI / 2
                        + (time * (0.52 + streak * 0.055)
                            + streak * Math.PI * 2 / 3) % (Math.PI * 2)
                    const streakPoints = []
                    for (let j = -7; j <= 7; ++j) {
                        const angle = centerAngle + j * 0.035
                        const sample = root.liquidSample(angle, time)
                        const inset = Math.max(1.5, sample.thickness * 0.28)
                        streakPoints.push({
                            x: sample.outerX - sample.nx * inset,
                            y: sample.outerY - sample.ny * inset
                        })
                    }
                    ctx.lineWidth = streak === 0 ? 2.1 : 1.35
                    ctx.strokeStyle = streak === 0
                        ? root.streakStrongColor : root.streakSoftColor
                    ctx.beginPath()
                    root.traceOpen(ctx, streakPoints)
                    ctx.stroke()
                }
            }
        }
    }
}
