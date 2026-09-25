pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common
import qs.modules.common.functions

// Continuous liquid-mass renderer for the Weather popup.
//
// Important: there is no orbital connector path in this component. The visible
// connector is the union of moving masses: 8 node masses plus 3 bridge
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
        Math.max(6.8, root.regularNodeRadius * 0.44)

    // The main body is deliberately opaque inside the Canvas. The Canvas item
    // itself carries translucency; this prevents overlapping masses from
    // revealing seams and makes them read as one continuous material.
    readonly property color bodyColor: ColorUtils.mix(
        Appearance.colors.colPrimaryContainer,
        Appearance.colors.colPrimary,
        0.42)
    readonly property color rimColor: ColorUtils.applyAlpha(
        Appearance.colors.colPrimary, 0.64)
    readonly property color glowColor: ColorUtils.applyAlpha(
        Appearance.colors.colPrimary, Appearance.effectsEnabled ? 0.58 : 0.28)
    readonly property color glowTransparent: ColorUtils.applyAlpha(
        Appearance.colors.colPrimary, 0)
    readonly property color foldLight: ColorUtils.applyAlpha(
        Appearance.colors.colPrimary, 0.48)
    readonly property color foldDark: ColorUtils.applyAlpha(
        Appearance.colors.colSurfaceContainerHigh, 0.33)
    readonly property color inactivePodCore: ColorUtils.applyAlpha(
        Appearance.colors.colSurfaceContainerHigh, 0.66)
    readonly property color inactivePodEdge: ColorUtils.applyAlpha(
        Appearance.colors.colPrimary, 0.32)
    readonly property color activePodCore: ColorUtils.applyAlpha(
        Appearance.colors.colSurfaceContainerHigh, 0.78)
    readonly property color activePodEdge: ColorUtils.applyAlpha(
        Appearance.colors.colPrimary, 0.84)

    readonly property bool ready: liquidShader.status === ShaderEffect.Compiled
        || liquidCanvas.available

    FrameAnimation {
        id: liquidClock
        property real lastPaintTime: -1
        running: root.animate
            && root.visible
            && root.hourAngles.length > 0
            && Appearance.animationsEnabled
        onTriggered: {
            // The full-size popup uses an image-backed canvas. Limit uploads
            // to 30 fps while keeping every mass moving with elapsed time.
            if (liquidCanvas.visible
                    && (lastPaintTime < 0
                        || elapsedTime - lastPaintTime >= 1 / 30)) {
                lastPaintTime = elapsedTime
                liquidCanvas.requestPaint()
            }
        }
        onRunningChanged: if (!running) lastPaintTime = -1
    }

    readonly property real timeSeconds: liquidClock.running
        ? liquidClock.elapsedTime
        : 0.73

    onHourAnglesChanged: liquidCanvas.requestPaint()
    onActiveIndexChanged: liquidCanvas.requestPaint()
    onBodyColorChanged: liquidCanvas.requestPaint()
    onRimColorChanged: liquidCanvas.requestPaint()
    onFoldLightChanged: liquidCanvas.requestPaint()

    function nodeX(index: int): real {
        if (index >= root.hourAngles.length)
            return -10000
        return root.width / 2
            + Math.cos(Number(root.hourAngles[index])) * root.orbitRadiusX
    }

    function nodeY(index: int): real {
        if (index >= root.hourAngles.length)
            return -10000
        return root.height / 2
            + Math.sin(Number(root.hourAngles[index])) * root.orbitRadiusY
    }

    // The GPU pass shades one soft-unioned signed-distance field at display
    // resolution. The image-backed Canvas below remains a compatibility path
    // for renderers that cannot compile the bundled Qt shader pack.
    ShaderEffect {
        id: liquidShader
        anchors.fill: parent
        visible: status === ShaderEffect.Compiled
        blending: true
        fragmentShader: Qt.resolvedUrl("LiquidOrbitalField.frag.qsb")

        readonly property vector2d fieldSize:
            Qt.vector2d(Math.max(1, root.width), Math.max(1, root.height))
        readonly property vector2d orbitRadii:
            Qt.vector2d(root.orbitRadiusX, root.orbitRadiusY)
        readonly property vector4d nodesX0: Qt.vector4d(
            root.nodeX(0), root.nodeX(1), root.nodeX(2), root.nodeX(3))
        readonly property vector4d nodesX1: Qt.vector4d(
            root.nodeX(4), root.nodeX(5), root.nodeX(6), root.nodeX(7))
        readonly property vector4d nodesY0: Qt.vector4d(
            root.nodeY(0), root.nodeY(1), root.nodeY(2), root.nodeY(3))
        readonly property vector4d nodesY1: Qt.vector4d(
            root.nodeY(4), root.nodeY(5), root.nodeY(6), root.nodeY(7))
        readonly property color bodyInk: Appearance.colors.colPrimaryContainer
        readonly property color accentInk: Appearance.colors.colPrimary
        readonly property color deepInk: Appearance.colors.colSurfaceContainerHigh
        readonly property color glintInk: Appearance.colors.colOnPrimaryContainer
        readonly property real seconds: root.timeSeconds
        readonly property real regularRadius: root.regularNodeRadius
        readonly property int selectedIndex: root.activeIndex
        readonly property int nodeCount: root.hourAngles.length
    }

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

    function drawPulseLobe(ctx, segment: int, slot: int, time: real,
                           grow: real, style): void {
        const count = root.hourAngles.length
        const start = Number(root.hourAngles[segment] ?? 0)
        const end = root.wrapForward(start,
            Number(root.hourAngles[(segment + 1) % count] ?? 0))
        const seed = segment * 1.57 + slot * 2.91
        const frame = root.ellipseFrame(start + (end - start)
            * (slot === 0 ? 0.36 : 0.64))
        const side = (segment + slot) % 2 === 0 ? 1 : -1
        const offset = side * root.bridgeMinorBase * (
            0.63 + 0.18 * Math.sin(time * 0.72 + seed))
        const radius = Math.max(2, root.bridgeMinorBase * (
            0.47 + 0.14 * Math.sin(time * 1.1 - seed)) + grow)
        root.fillEllipse(ctx,
            frame.cx + frame.nx * offset,
            frame.cy + frame.ny * offset,
            radius * 1.35, radius,
            Math.atan2(frame.ty, frame.tx), style)
    }

    // One segment owns exactly three bridge masses. They are not samples of a
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
        const fraction = slot === 0 ? 0.24 : slot === 1 ? 0.50 : 0.76
        const seed = segment * 1.731 + slot * 2.413
        const baseAngle = start + span * fraction
        const frame = root.ellipseFrame(baseAngle)

        // Translation of the mass itself. Independent tangent + normal motion
        // is what makes the connector slosh instead of wobbling like a stroke.
        const movementScale = root.regularNodeRadius / 24
        const tangentOffset = movementScale * (
            Math.sin(time * 0.57 + seed) * 2.8
            + Math.sin(time * 0.21 - seed * 0.8) * 0.9)
        const normalOffset = movementScale * (
            Math.sin(time * 0.83 + seed * 1.7) * 3.4
            + Math.sin(time * 1.29 - seed) * 1.2)

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

        const major = (Math.max(root.regularNodeRadius * 0.9,
                arcLength * 0.33)
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
            root.drawBridgeMass(ctx, segment, 2, time, grow, style, 1)
            root.drawPulseLobe(ctx, segment, 0, time, grow, style)
            root.drawPulseLobe(ctx, segment, 1, time, grow, style)
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
        const glowRadius = radius * (2.55 + 0.06 * Math.sin(time * 0.93))
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
        gradient.addColorStop(0.28, active
            ? root.activePodCore : root.inactivePodCore)
        gradient.addColorStop(0.73, active
            ? root.activePodCore : root.inactivePodCore)
        gradient.addColorStop(1, active
            ? root.activePodEdge : root.inactivePodEdge)
        ctx.fillStyle = gradient
        ctx.beginPath()
        ctx.arc(frame.cx, frame.cy, radius * 0.955, 0, Math.PI * 2)
        ctx.fill()
    }

    // Translucent folds flow inside the union. They change curvature and
    // thickness independently of the silhouettes, like light passing through
    // different depths of one sheet of liquid.
    function drawFlowFold(ctx, segment: int, side: real, time: real): void {
        const count = root.hourAngles.length
        const start = Number(root.hourAngles[segment] ?? 0)
        const end = root.wrapForward(start,
            Number(root.hourAngles[(segment + 1) % count] ?? 0))
        const span = end - start
        const seed = segment * 1.41 + side * 2.27
        const wave = Math.sin(time * 0.69 + seed) * root.bridgeMinorBase * 0.26
        const drift = Math.sin(time * 0.37 - seed) * root.bridgeMinorBase * 0.13
        const offset = side * root.bridgeMinorBase * 0.53 + drift

        function point(fraction, normalOffset) {
            const frame = root.ellipseFrame(start + span * fraction)
            return {
                x: frame.cx + frame.nx * normalOffset,
                y: frame.cy + frame.ny * normalOffset
            }
        }

        const near = point(0.07, offset)
        const far = point(0.93, offset)
        const upperA = point(0.33, offset + wave + side * root.bridgeMinorBase * 0.34)
        const upperB = point(0.67, offset - wave + side * root.bridgeMinorBase * 0.25)
        const lowerA = point(0.33, offset + wave - side * root.bridgeMinorBase * 0.32)
        const lowerB = point(0.67, offset - wave - side * root.bridgeMinorBase * 0.42)
        const mid = point(0.50, offset)
        const normal = root.ellipseFrame(start + span * 0.5)
        const gradient = ctx.createLinearGradient(
            mid.x - normal.nx * root.bridgeMinorBase,
            mid.y - normal.ny * root.bridgeMinorBase,
            mid.x + normal.nx * root.bridgeMinorBase,
            mid.y + normal.ny * root.bridgeMinorBase)
        gradient.addColorStop(0, side > 0 ? root.foldDark : root.foldLight)
        gradient.addColorStop(0.5, ColorUtils.applyAlpha(
            Appearance.colors.colPrimary, 0.04))
        gradient.addColorStop(1, side > 0 ? root.foldLight : root.foldDark)

        ctx.fillStyle = gradient
        ctx.beginPath()
        ctx.moveTo(near.x, near.y)
        ctx.bezierCurveTo(upperA.x, upperA.y, upperB.x, upperB.y,
            far.x, far.y)
        ctx.bezierCurveTo(lowerB.x, lowerB.y, lowerA.x, lowerA.y,
            near.x, near.y)
        ctx.closePath()
        ctx.fill()
    }

    function drawVoidChannel(ctx, segment: int, time: real): void {
        const count = root.hourAngles.length
        const start = Number(root.hourAngles[segment] ?? 0)
        const end = root.wrapForward(start,
            Number(root.hourAngles[(segment + 1) % count] ?? 0))
        const span = end - start
        const wave = Math.sin(time * 0.78 + segment * 1.83)
            * root.bridgeMinorBase * 0.28
        function point(fraction, offset) {
            const frame = root.ellipseFrame(start + span * fraction)
            return {
                x: frame.cx + frame.nx * offset,
                y: frame.cy + frame.ny * offset
            }
        }
        const near = point(0.11, -root.bridgeMinorBase * 0.30)
        const far = point(0.89, -root.bridgeMinorBase * 0.18)
        const highA = point(0.37, -root.bridgeMinorBase * 0.09 + wave)
        const highB = point(0.68, -root.bridgeMinorBase * 0.26 - wave)
        const lowA = point(0.34, -root.bridgeMinorBase * 0.82 + wave)
        const lowB = point(0.65, -root.bridgeMinorBase * 0.68 - wave)
        ctx.beginPath()
        ctx.moveTo(near.x, near.y)
        ctx.bezierCurveTo(highA.x, highA.y, highB.x, highB.y,
            far.x, far.y)
        ctx.bezierCurveTo(lowB.x, lowB.y, lowA.x, lowA.y,
            near.x, near.y)
        ctx.closePath()
        ctx.fill()
    }

    Canvas {
        id: liquidCanvas
        anchors.fill: parent
        visible: liquidShader.status !== ShaderEffect.Compiled
        antialiasing: true
        renderStrategy: Canvas.Threaded
        renderTarget: Canvas.Image
        // Group translucency keeps the opaque mass union seamless.
        opacity: 1

        onAvailableChanged: if (available) requestPaint()
        onWidthChanged: if (available) requestPaint()
        onHeightChanged: if (available) requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            if (width <= 0 || height <= 0 || root.hourAngles.length < 2)
                return

            const time = root.timeSeconds

            // 1. Morphological rim: a slightly enlarged mass union underneath
            // the body. No stroke/path is used to outline the connector.
            root.drawMassUnion(ctx, time,
                Math.max(2.1, root.regularNodeRadius * 0.055), root.rimColor)

            // 2. Main continuous liquid body. Every overlapping mass is opaque
            // at this stage, so bridges/nodes have no intersection seams.
            root.drawMassUnion(ctx, time, 0, root.bodyColor)

            // 3. A broad refractive wash and moving translucent folds stay
            // inside the union silhouette.
            ctx.save()
            ctx.globalCompositeOperation = "source-atop"
            const wash = ctx.createLinearGradient(0, 0, width, height)
            wash.addColorStop(0, ColorUtils.applyAlpha(
                Appearance.colors.colPrimary, 0.18))
            wash.addColorStop(0.5, ColorUtils.applyAlpha(
                Appearance.colors.colOnPrimaryContainer, 0.09))
            wash.addColorStop(1, ColorUtils.applyAlpha(
                Appearance.colors.colPrimary, 0.21))
            ctx.fillStyle = wash
            ctx.fillRect(0, 0, width, height)
            for (let segment = 0; segment < root.hourAngles.length; ++segment) {
                root.drawFlowFold(ctx, segment, -1, time)
                root.drawFlowFold(ctx, segment, 1, time)
            }
            ctx.restore()

            // Lower the alpha of the *completed* union in one operation. This
            // makes the connector translucent without exposing overlap seams.
            ctx.save()
            ctx.globalCompositeOperation = "destination-out"
            ctx.fillStyle = "rgba(0, 0, 0, 0.40)"
            ctx.fillRect(0, 0, width, height)
            ctx.fillStyle = "rgba(0, 0, 0, 0.46)"
            for (let segment = 0; segment < root.hourAngles.length; ++segment)
                root.drawVoidChannel(ctx, segment, time)
            ctx.restore()

            // Glass pods stay more solid than the fluid between them.
            for (let index = 0; index < root.hourAngles.length; ++index)
                root.drawPodVolume(ctx, index, time)

            // 5. The active halo is composited behind the continuous body.
            ctx.save()
            ctx.globalCompositeOperation = "destination-over"
            root.drawActiveGlow(ctx, time)
            ctx.restore()
        }
    }
}
