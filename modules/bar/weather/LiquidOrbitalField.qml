pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common
import qs.modules.common.functions

// Continuous liquid-mass renderer for the Weather popup.
//
// Important: there is no orbital connector path in this component. The visible
// connector is only the union of moving masses: 8 node masses plus 2 bridge
// masses per segment. Their positions, aspect ratios and orientation deform on
// every scene frame, so the connector itself changes silhouette continuously.
Item {
    id: root

    property var hourAngles: []
    property real orbitRadiusX: 1
    property real orbitRadiusY: 1
    property real nodeWidth: 48
    property real nodeHeight: 48
    property int activeIndex: 0
    property bool animate: false

    readonly property real regularNodeRadius:
        Math.max(14, Math.min(root.nodeWidth, root.nodeHeight) * 0.5)
    readonly property real activeNodeScale: 1.28
    readonly property real bridgeMinorBase:
        Math.max(6.8, Math.min(10.0, root.regularNodeRadius * 0.46))

    // The main body is deliberately opaque inside the Canvas. The Canvas item
    // itself carries translucency; this prevents overlapping masses from
    // revealing seams and makes them read as one continuous material.
    readonly property color bodyColor: ColorUtils.mix(
        Appearance.colors.colSurfaceContainerHigh,
        Appearance.colors.colPrimaryContainer,
        0.58)
    readonly property color rimColor: ColorUtils.applyAlpha(
        Appearance.colors.colPrimary, 0.34)
    readonly property color glowColor: ColorUtils.applyAlpha(
        Appearance.colors.colPrimary, Appearance.effectsEnabled ? 0.28 : 0.14)
    readonly property color glowTransparent: ColorUtils.applyAlpha(
        Appearance.colors.colPrimary, 0)
    readonly property color sheetColorA: ColorUtils.applyAlpha(
        Appearance.colors.colPrimaryContainer, 0.14)
    readonly property color sheetColorB: ColorUtils.applyAlpha(
        Appearance.colors.colOnPrimaryContainer, 0.10)
    readonly property color inactivePodCore: ColorUtils.applyAlpha(
        Appearance.colors.colSurfaceContainerHigh, 0.74)
    readonly property color inactivePodEdge: ColorUtils.applyAlpha(
        Appearance.colors.colPrimaryContainer, 0.22)
    readonly property color activePodCore: ColorUtils.applyAlpha(
        ColorUtils.mix(Appearance.colors.colPrimaryContainer,
            Appearance.colors.colPrimary, 0.34), 0.82)
    readonly property color activePodEdge: ColorUtils.applyAlpha(
        Appearance.colors.colPrimary, 0.46)

    readonly property bool ready: true

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

    function wrapForward(start: real, end: real): real {
        let result = end
        while (result <= start)
            result += Math.PI * 2
        return result
    }

    function ellipseFrame(angle: real): var {
        const c = Math.cos(angle)
        const s = Math.sin(angle)
        const cx = root.width / 2 + c * root.orbitRadiusX
        const cy = root.height / 2 + s * root.orbitRadiusY
        const txRaw = -root.orbitRadiusX * s
        const tyRaw = root.orbitRadiusY * c
        const speed = Math.max(0.001,
            Math.sqrt(txRaw * txRaw + tyRaw * tyRaw))
        const tx = txRaw / speed
        const ty = tyRaw / speed
        // Outward unit normal.
        const nx = ty
        const ny = -tx
        return { cx, cy, tx, ty, nx, ny, speed }
    }

    function nodeRadius(index: int, time: real): real {
        const active = index === root.activeIndex
        const base = root.regularNodeRadius * (active ? root.activeNodeScale : 1)
        const breathing = Math.sin(time * (active ? 1.08 : 0.72)
            + index * 1.47) * (active ? 1.35 : 0.55)
        return Math.max(8, base + breathing)
    }

    function fillEllipse(ctx, cx: real, cy: real, rx: real, ry: real,
                         rotation: real, style): void {
        if (rx <= 0.1 || ry <= 0.1)
            return
        ctx.save()
        ctx.translate(cx, cy)
        ctx.rotate(rotation)
        ctx.scale(rx, ry)
        ctx.fillStyle = style
        ctx.beginPath()
        ctx.arc(0, 0, 1, 0, Math.PI * 2)
        ctx.fill()
        ctx.restore()
    }

    function drawNodeMass(ctx, index: int, time: real, grow: real,
                          style): void {
        if (index < 0 || index >= root.hourAngles.length)
            return
        const angle = Number(root.hourAngles[index] ?? 0)
        const frame = root.ellipseFrame(angle)
        const radius = root.nodeRadius(index, time) + grow
        root.fillEllipse(ctx, frame.cx, frame.cy, radius, radius, 0, style)
    }

    // One segment owns exactly two bridge masses. They are not samples of a
    // stroked path: each bridge is an independent anisotropic liquid body.
    // Because the bodies overlap one another and the node masses, their union
    // creates the visible connector with no line geometry anywhere.
    function drawBridgeMass(ctx, segment: int, slot: int, time: real,
                            grow: real, style, innerScale: real): void {
        const count = root.hourAngles.length
        if (count < 2)
            return

        const start = Number(root.hourAngles[segment] ?? 0)
        const nextIndex = (segment + 1) % count
        const end = root.wrapForward(start,
            Number(root.hourAngles[nextIndex] ?? 0))
        const span = end - start
        const fraction = slot === 0 ? 0.32 : 0.68
        const seed = segment * 1.731 + slot * 2.413
        const baseAngle = start + span * fraction
        const frame = root.ellipseFrame(baseAngle)

        // Translation of the mass itself. Independent tangent + normal motion
        // is what makes the connector slosh instead of wobbling like a stroke.
        const tangentOffset = Math.sin(time * 0.57 + seed) * 2.8
            + Math.sin(time * 0.21 - seed * 0.8) * 0.9
        const normalOffset = Math.sin(time * 0.83 + seed * 1.7) * 3.4
            + Math.sin(time * 1.29 - seed) * 1.2

        const cx = frame.cx
            + frame.tx * tangentOffset
            + frame.nx * normalOffset
        const cy = frame.cy
            + frame.ty * tangentOffset
            + frame.ny * normalOffset

        // Approximate this segment's arc length. The bridge is intentionally
        // much longer along the tangent than along the normal; independently
        // pulsing both axes changes the actual neck cross-section continuously.
        const arcLength = frame.speed * span
        const adjacentActive = segment === root.activeIndex
            || nextIndex === root.activeIndex
        const majorPulse = 1
            + Math.sin(time * 0.64 + seed) * 0.08
            + Math.sin(time * 0.31 - seed * 0.6) * 0.035
        const minorPulse = 1
            + Math.sin(time * 0.91 + seed * 1.2) * 0.23
            + Math.sin(time * 1.37 - seed) * 0.08

        const major = (Math.max(23, Math.min(34, arcLength * 0.37))
            * majorPulse + grow) * innerScale
        const minor = ((root.bridgeMinorBase + (adjacentActive ? 1.8 : 0))
            * minorPulse + grow) * innerScale
        const rotation = Math.atan2(frame.ty, frame.tx)
            + Math.sin(time * 0.46 + seed * 0.9) * 0.12

        root.fillEllipse(ctx, cx, cy,
            Math.max(1, major), Math.max(1, minor), rotation, style)
    }

    function drawMassUnion(ctx, time: real, grow: real, style): void {
        const count = root.hourAngles.length
        // Bridges first, nodes last. All are opaque in the body pass, therefore
        // overlap produces one seamless connected silhouette rather than darker
        // intersection patches.
        for (let segment = 0; segment < count; ++segment) {
            root.drawBridgeMass(ctx, segment, 0, time, grow, style, 1)
            root.drawBridgeMass(ctx, segment, 1, time, grow, style, 1)
        }
        for (let index = 0; index < count; ++index)
            root.drawNodeMass(ctx, index, time, grow, style)
    }

    function drawActiveGlow(ctx, time: real): void {
        if (root.activeIndex < 0 || root.activeIndex >= root.hourAngles.length)
            return
        const angle = Number(root.hourAngles[root.activeIndex] ?? 0)
        const frame = root.ellipseFrame(angle)
        const radius = root.nodeRadius(root.activeIndex, time)
        const glowRadius = radius * (2.05 + 0.06 * Math.sin(time * 0.93))
        const gradient = ctx.createRadialGradient(
            frame.cx, frame.cy, radius * 0.28,
            frame.cx, frame.cy, glowRadius)
        gradient.addColorStop(0, root.glowColor)
        gradient.addColorStop(1, root.glowTransparent)
        ctx.fillStyle = gradient
        ctx.beginPath()
        ctx.arc(frame.cx, frame.cy, glowRadius, 0, Math.PI * 2)
        ctx.fill()
    }

    function drawPodVolume(ctx, index: int, time: real): void {
        const angle = Number(root.hourAngles[index] ?? 0)
        const frame = root.ellipseFrame(angle)
        const radius = root.nodeRadius(index, time)
        const active = index === root.activeIndex
        const gx = frame.cx - radius * 0.20
        const gy = frame.cy - radius * 0.26
        const gradient = ctx.createRadialGradient(
            gx, gy, radius * 0.06,
            frame.cx, frame.cy, radius * 0.98)
        gradient.addColorStop(0, active
            ? root.activePodEdge : root.inactivePodEdge)
        gradient.addColorStop(0.48, active
            ? root.activePodCore : root.inactivePodCore)
        gradient.addColorStop(1, ColorUtils.applyAlpha(
            Appearance.colors.colSurfaceContainerHigh, 0.30))
        ctx.fillStyle = gradient
        ctx.beginPath()
        ctx.arc(frame.cx, frame.cy, radius * 0.955, 0, Math.PI * 2)
        ctx.fill()
    }

    // Internal highlights are also moving masses, not strokes. Their smaller
    // ellipses drift inside the bridges at another cadence and produce the
    // folded translucent look of the supplied concept while preserving the
    // mass-derived silhouette as the only connector geometry.
    function drawBridgeSheets(ctx, time: real): void {
        const count = root.hourAngles.length
        for (let segment = 0; segment < count; ++segment) {
            for (let slot = 0; slot < 2; ++slot) {
                const style = ((segment + slot) % 2 === 0)
                    ? root.sheetColorA : root.sheetColorB
                root.drawBridgeMass(ctx, segment, slot,
                    time + 0.86 + slot * 0.37,
                    -2.6, style, slot === 0 ? 0.72 : 0.62)
            }
        }
    }

    Canvas {
        id: liquidCanvas
        anchors.fill: parent
        antialiasing: true
        renderStrategy: Canvas.Threaded
        renderTarget: Canvas.Image
        // Group translucency keeps the opaque mass union seamless.
        opacity: Appearance.effectsEnabled ? 0.78 : 0.70

        onAvailableChanged: if (available) requestPaint()
        onWidthChanged: if (available) requestPaint()
        onHeightChanged: if (available) requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            if (width <= 0 || height <= 0 || root.hourAngles.length < 2)
                return

            const time = root.timeSeconds

            // 1. Active energy halo.
            root.drawActiveGlow(ctx, time)

            // 2. Morphological rim: a slightly enlarged mass union underneath
            // the body. No stroke/path is used to outline the connector.
            root.drawMassUnion(ctx, time, 2.1, root.rimColor)

            // 3. Main continuous liquid body. Every overlapping mass is opaque
            // at this stage, so bridges/nodes have no intersection seams.
            root.drawMassUnion(ctx, time, 0, root.bodyColor)

            // 4. Dark glass volume inside the 8 node lobes.
            for (let index = 0; index < root.hourAngles.length; ++index)
                root.drawPodVolume(ctx, index, time)

            // 5. Smaller moving masses create internal folded/caustic volume.
            root.drawBridgeSheets(ctx, time)
        }
    }
}
