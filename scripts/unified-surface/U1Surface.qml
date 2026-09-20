pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    required property ShellScreen modelData

    function envReal(name, fallback) {
        const parsed = Number(Quickshell.env(name))
        return Number.isFinite(parsed) ? parsed : fallback
    }

    function envBool(name, fallback) {
        const value = String(Quickshell.env(name) || "").toLowerCase()
        if (value === "1" || value === "true" || value === "yes")
            return true
        if (value === "0" || value === "false" || value === "no")
            return false
        return fallback
    }

    function clamp(value, lo, hi) {
        return Math.max(lo, Math.min(hi, value))
    }

    function mix(a, b, t) {
        return a + (b - a) * t
    }

    readonly property string edge: {
        const candidate = (Quickshell.env("HADALIS_U1_EDGE") || "top").toLowerCase()
        return ["top", "bottom", "left", "right"].includes(candidate) ? candidate : "top"
    }
    readonly property string layerMode:
        (Quickshell.env("HADALIS_U1_LAYER") || "overlay").toLowerCase() === "top"
            ? "top" : "overlay"
    readonly property string renderMode: {
        const candidate = (Quickshell.env("HADALIS_U1_MODE") || "bounded").toLowerCase()
        return ["control", "bounded", "full"].includes(candidate) ? candidate : "bounded"
    }
    readonly property bool horizontal: edge === "top" || edge === "bottom"
    readonly property real dpr: Math.max(1, modelData?.devicePixelRatio ?? 1)
    readonly property real edgeThickness: Math.max(1, envReal("HADALIS_U1_EDGE_THICKNESS", 10))
    readonly property real ownerThickness: Math.max(
        edgeThickness,
        envReal("HADALIS_U1_OWNER_THICKNESS", horizontal ? 40 : 46)
    )
    readonly property real frameRadius: Math.max(0, envReal("HADALIS_U1_FRAME_RADIUS", 25))
    readonly property real popupRadius: Math.max(0, envReal("HADALIS_U1_POPUP_RADIUS", 32))
    readonly property real smoothK: Math.max(1, envReal("HADALIS_U1_SMOOTH_K", 28))
    readonly property real popupWidth: Math.max(40, envReal("HADALIS_U1_POPUP_WIDTH", horizontal ? 320 : 260))
    readonly property real popupHeight: Math.max(40, envReal("HADALIS_U1_POPUP_HEIGHT", horizontal ? 220 : 340))
    readonly property color materialColor: Quickshell.env("HADALIS_U1_COLOR") || "#e6e0e9"
    readonly property bool animateSource: envBool("HADALIS_U1_ANIMATE", true)
    readonly property bool cycleReveal: envBool("HADALIS_U1_REVEAL_CYCLE", false)
    readonly property bool benchmarkEnabled: envBool("HADALIS_U1_BENCHMARK", false)
    readonly property bool traceGeometry: envBool("HADALIS_U1_TRACE_GEOMETRY", false)
    readonly property real targetHz: Math.max(1, envReal("HADALIS_U1_TARGET_HZ", 60))
    readonly property int warmupFrames: Math.max(0, Math.round(envReal("HADALIS_U1_WARMUP_FRAMES", 120)))
    readonly property int sampleFrames: Math.max(60, Math.round(envReal("HADALIS_U1_SAMPLE_FRAMES", 600)))

    // U1 lifecycle invariant: this layer-shell surface stays mapped. Quickshell
    // destroys WlrLayershell backing windows when PanelWindow.visible becomes false.
    // Only child rendering state is toggled.
    screen: modelData
    visible: true
    updatesEnabled: true
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    focusable: false

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.namespace: "hadalis:u1-unified-surface-" + layerMode
    WlrLayershell.layer: layerMode === "top" ? WlrLayer.Top : WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Item {
        id: emptyInput
        width: 0
        height: 0
        visible: false
    }
    mask: Region { item: emptyInput }

    // Semantic geometry remains in output-local logical coordinates.
    readonly property rect frameOuter: Qt.rect(0, 0, width, height)
    readonly property real innerLeft: edge === "left" ? ownerThickness : edgeThickness
    readonly property real innerTop: edge === "top" ? ownerThickness : edgeThickness
    readonly property real innerRight: width - (edge === "right" ? ownerThickness : edgeThickness)
    readonly property real innerBottom: height - (edge === "bottom" ? ownerThickness : edgeThickness)
    readonly property rect frameInner: Qt.rect(
        innerLeft,
        innerTop,
        Math.max(0, innerRight - innerLeft),
        Math.max(0, innerBottom - innerTop)
    )

    // Fake module anchor. Moving it changes only popup placement data; the shader
    // has no module identity, edge-contact flag, or corner-selection state.
    property real sourceT: clamp(envReal("HADALIS_U1_SOURCE_T", 0.5), 0, 1)
    property real reveal: 1.0
    readonly property real tangentCenter: horizontal
        ? width * sourceT
        : height * sourceT

    readonly property rect popupRect: {
        const pw = Math.min(popupWidth, Math.max(1, width))
        const ph = Math.min(popupHeight, Math.max(1, height))

        if (edge === "top") {
            const x = clamp(tangentCenter - pw / 2, 0, Math.max(0, width - pw))
            // At rest the popup begins exactly at the inner owner seam. Reveal
            // translates the full rect underneath the owner; no permanent
            // penetration/contact offset is part of semantic geometry.
            const restingY = innerTop
            const hiddenY = innerTop - ph
            return Qt.rect(x, mix(hiddenY, restingY, reveal), pw, ph)
        }
        if (edge === "bottom") {
            const x = clamp(tangentCenter - pw / 2, 0, Math.max(0, width - pw))
            const restingY = innerBottom - ph
            const hiddenY = innerBottom
            return Qt.rect(x, mix(hiddenY, restingY, reveal), pw, ph)
        }
        if (edge === "left") {
            const y = clamp(tangentCenter - ph / 2, 0, Math.max(0, height - ph))
            const restingX = innerLeft
            const hiddenX = innerLeft - pw
            return Qt.rect(mix(hiddenX, restingX, reveal), y, pw, ph)
        }

        const y = clamp(tangentCenter - ph / 2, 0, Math.max(0, height - ph))
        const restingX = innerRight - pw
        const hiddenX = innerRight
        return Qt.rect(mix(hiddenX, restingX, reveal), y, pw, ph)
    }

    function alignDown(value) {
        return Math.floor(value * dpr) / dpr
    }

    function alignUp(value) {
        return Math.ceil(value * dpr) / dpr
    }

    readonly property rect boundedEffectRect: {
        const pad = 2 * smoothK + 2 / dpr
        let x0
        let y0
        let x1
        let y1

        if (edge === "top") {
            x0 = popupRect.x - pad
            x1 = popupRect.x + popupRect.width + pad
            y0 = 0
            y1 = popupRect.y + popupRect.height + pad
        } else if (edge === "bottom") {
            x0 = popupRect.x - pad
            x1 = popupRect.x + popupRect.width + pad
            y0 = popupRect.y - pad
            y1 = height
        } else if (edge === "left") {
            x0 = 0
            x1 = popupRect.x + popupRect.width + pad
            y0 = popupRect.y - pad
            y1 = popupRect.y + popupRect.height + pad
        } else {
            x0 = popupRect.x - pad
            x1 = width
            y0 = popupRect.y - pad
            y1 = popupRect.y + popupRect.height + pad
        }

        x0 = alignDown(clamp(x0, 0, width))
        y0 = alignDown(clamp(y0, 0, height))
        x1 = alignUp(clamp(x1, 0, width))
        y1 = alignUp(clamp(y1, 0, height))
        return Qt.rect(x0, y0, Math.max(1 / dpr, x1 - x0), Math.max(1 / dpr, y1 - y0))
    }

    readonly property rect effectRect: renderMode === "full"
        ? Qt.rect(0, 0, width, height)
        : boundedEffectRect

    ShaderEffect {
        id: sdf
        x: root.effectRect.x
        y: root.effectRect.y
        width: root.effectRect.width
        height: root.effectRect.height
        visible: root.renderMode !== "control" && width > 0 && height > 0

        property real smoothK: root.smoothK
        property real frameRadius: root.frameRadius
        property real popupRadius: root.popupRadius
        property rect effectRect: root.effectRect
        property rect frameOuter: root.frameOuter
        property rect frameInner: root.frameInner
        property rect popupRect: root.popupRect
        property color materialColor: root.materialColor

        fragmentShader: Qt.resolvedUrl("U1Surface.qsb")
    }

    SequentialAnimation on sourceT {
        running: root.animateSource
        loops: Animation.Infinite
        NumberAnimation { from: 0.08; to: 0.92; duration: 2600; easing.type: Easing.InOutSine }
        NumberAnimation { from: 0.92; to: 0.08; duration: 2600; easing.type: Easing.InOutSine }
    }

    SequentialAnimation on reveal {
        running: root.cycleReveal
        loops: Animation.Infinite
        NumberAnimation { from: 0; to: 1; duration: 650; easing.type: Easing.OutCubic }
        PauseAnimation { duration: 650 }
        NumberAnimation { from: 1; to: 0; duration: 650; easing.type: Easing.InCubic }
        PauseAnimation { duration: 350 }
    }

    function rectObject(value) {
        return {
            x: value.x,
            y: value.y,
            width: value.width,
            height: value.height
        }
    }

    function geometryReport() {
        return {
            version: 1,
            output: String(modelData?.name ?? ""),
            edge: edge,
            layer: layerMode,
            mode: renderMode,
            dpr: dpr,
            width: width,
            height: height,
            sourceT: sourceT,
            reveal: reveal,
            smoothK: smoothK,
            frameOuter: rectObject(frameOuter),
            frameInner: rectObject(frameInner),
            popupRect: rectObject(popupRect),
            effectRect: rectObject(effectRect)
        }
    }

    property var benchmarkSamples: []
    property int benchmarkSeen: 0
    property bool benchmarkReported: false

    function percentile(sorted, q) {
        if (sorted.length === 0)
            return 0
        const index = Math.min(sorted.length - 1, Math.max(0, Math.ceil(q * sorted.length) - 1))
        return sorted[index]
    }

    function recordFrame(seconds) {
        if (!benchmarkEnabled || benchmarkReported || seconds <= 0)
            return

        benchmarkSeen++
        if (benchmarkSeen <= warmupFrames)
            return

        const next = benchmarkSamples.concat([seconds * 1000])
        benchmarkSamples = next
        if (next.length < sampleFrames)
            return

        const sorted = next.slice().sort((a, b) => a - b)
        const mean = next.reduce((sum, value) => sum + value, 0) / next.length
        const budget = 1000 / targetHz
        const missed = next.filter(value => value > budget * 1.5).length
        const report = {
            version: 1,
            output: String(modelData?.name ?? ""),
            edge: edge,
            layer: layerMode,
            mode: renderMode,
            dpr: dpr,
            width: width,
            height: height,
            effectWidth: effectRect.width,
            effectHeight: effectRect.height,
            targetHz: targetHz,
            samples: next.length,
            meanMs: mean,
            p50Ms: percentile(sorted, 0.50),
            p95Ms: percentile(sorted, 0.95),
            p99Ms: percentile(sorted, 0.99),
            maxMs: sorted[sorted.length - 1],
            missedRatio: missed / next.length
        }
        benchmarkReported = true
        console.log("HADALIS_U1_BENCHMARK " + JSON.stringify(report))
    }

    FrameAnimation {
        running: root.benchmarkEnabled && !root.benchmarkReported
        onTriggered: root.recordFrame(frameTime)
    }

    Timer {
        interval: root.traceGeometry ? 100 : 50
        repeat: true
        running: true
        onTriggered: {
            if (root.width <= 0 || root.height <= 0)
                return
            console.log("HADALIS_U1_GEOMETRY " + JSON.stringify(root.geometryReport()))
            if (!root.traceGeometry)
                stop()
        }
    }

    Component.onCompleted: {
        console.log("[Hadalis U1] output=" + String(modelData?.name ?? "")
            + " edge=" + edge
            + " layer=" + layerMode
            + " mode=" + renderMode
            + " dpr=" + dpr)
    }
}
