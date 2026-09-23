pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.perimeter

// One-pass liquid substrate for the Weather popup.
//
// The field reuses Hadalis' production iRiS SDF/QSB. Twelve softly joined
// tangent bodies form a closed ribbon and the eight hourly bodies melt into the
// same union. The body objects are persistent QtObjects: only numeric bindings
// move on each scene frame, avoiding per-frame JS object/list allocation.
Item {
    id: root

    property var hourAngles: []
    property real orbitRadiusX: 1
    property real orbitRadiusY: 1
    property real nodeWidth: 48
    property real nodeHeight: 58
    property int activeIndex: 0
    property bool animate: false

    readonly property int ribbonCount: 12
    readonly property real fuseDepth: 36
    readonly property real baseThickness: Math.max(14,
        Math.min(20, Math.min(root.nodeWidth, root.nodeHeight) * 0.38))
    readonly property real ribbonSpan: Math.max(24,
        Math.min(38, Math.min(root.nodeWidth, root.nodeHeight) * 0.72))
    readonly property color fieldColor: ColorUtils.applyAlpha(
        ColorUtils.mix(
            Appearance.colors.colSurfaceContainerHigh,
            Appearance.colors.colPrimaryContainer,
            0.72),
        0.92)
    readonly property color edgeColor: ColorUtils.applyAlpha(
        Appearance.colors.colPrimary, 0.66)
    readonly property bool shaderCompiled: field.shaderCompiled
    readonly property bool shaderFailed:
        field.shaderStatus === ShaderEffect.Error
    readonly property string shaderLog: field.shaderLog

    // Scene-frame cadence rather than a fixed 16 ms Timer. elapsedTime is real
    // time, so missed frames advance the phase instead of slowing the material.
    FrameAnimation {
        id: liquidClock
        running: root.animate
            && root.visible
            && root.hourAngles.length > 0
            && Appearance.animationsEnabled
            && Appearance.effectsEnabled
    }

    readonly property real phase: liquidClock.running
        ? liquidClock.elapsedTime * (Math.PI * 2 / 12.0)
        : 0.73

    // Equal arc-length samples keep the twelve ribbon bodies visually even on
    // the deliberately wide ellipse. This binding only changes on resize, not
    // on every animation frame.
    readonly property var ribbonAngles: {
        const samples = 192
        const lengths = [0]
        const start = -Math.PI / 2
        let total = 0
        let previousX = Math.cos(start) * root.orbitRadiusX
        let previousY = Math.sin(start) * root.orbitRadiusY

        for (let sample = 1; sample <= samples; ++sample) {
            const t = sample / samples
            const angle = start + t * Math.PI * 2
            const x = Math.cos(angle) * root.orbitRadiusX
            const y = Math.sin(angle) * root.orbitRadiusY
            total += Math.sqrt(
                (x - previousX) * (x - previousX)
                + (y - previousY) * (y - previousY))
            lengths.push(total)
            previousX = x
            previousY = y
        }

        const result = []
        for (let index = 0; index < root.ribbonCount; ++index) {
            const target = total * index / root.ribbonCount
            let sample = 1
            while (sample < lengths.length && lengths[sample] < target)
                ++sample
            const before = lengths[Math.max(0, sample - 1)]
            const span = Math.max(0.0001, lengths[sample] - before)
            const local = (target - before) / span
            const t = (sample - 1 + local) / samples
            result.push(start + t * Math.PI * 2)
        }
        return result
    }

    function nearestRibbonIndex(angle: real): int {
        const angles = root.ribbonAngles ?? []
        let bestIndex = 0
        let bestDistance = Number.POSITIVE_INFINITY
        for (let i = 0; i < angles.length; ++i) {
            let delta = Math.abs(angle - Number(angles[i]))
            delta = Math.min(delta, Math.PI * 2 - delta)
            if (delta < bestDistance) {
                bestDistance = delta
                bestIndex = i
            }
        }
        return bestIndex
    }

    readonly property var hourRibbonIndices: {
        const result = []
        const angles = root.hourAngles ?? []
        for (let i = 0; i < angles.length; ++i)
            result.push(root.nearestRibbonIndex(Number(angles[i] ?? 0)))
        return result
    }

    component LiquidBody: QtObject {
        required property bool ribbon
        required property int index

        readonly property bool enabledBody: ribbon
            || index < (root.hourAngles?.length ?? 0)
        readonly property bool active: !ribbon && index === root.activeIndex
        readonly property real angle: ribbon
            ? Number(root.ribbonAngles[index] ?? 0)
            : Number(root.hourAngles[index] ?? 0)

        readonly property real cosAngle: Math.cos(angle)
        readonly property real sinAngle: Math.sin(angle)
        readonly property real tangentXRaw: -root.orbitRadiusX * sinAngle
        readonly property real tangentYRaw: root.orbitRadiusY * cosAngle
        readonly property real tangentLength: Math.max(1,
            Math.sqrt(tangentXRaw * tangentXRaw
                + tangentYRaw * tangentYRaw))
        readonly property real tangentX: tangentXRaw / tangentLength
        readonly property real tangentY: tangentYRaw / tangentLength

        readonly property real wave: !ribbon ? 0
            : liquidClock.running
                ? Math.sin(root.phase * 0.93 + index * 1.37) * 1.6
                    + Math.sin(root.phase * 0.47 - index * 0.81) * 0.7
                : Math.sin(index * 1.37 + 0.73) * 0.8
        readonly property real tangential: !ribbon || !liquidClock.running
            ? 0
            : Math.sin(root.phase * 0.61 - index * 1.11) * 0.8
        readonly property real thicknessPulse: !ribbon ? 0
            : liquidClock.running
                ? Math.sin(root.phase * 0.39 + index * 1.57) * 1.15
                    + Math.sin(root.phase * 0.22 - index * 0.73) * 0.45
                : Math.sin(index * 1.57 + 0.73) * 0.35
        readonly property real breathing: ribbon ? 0
            : liquidClock.running
                ? Math.sin(root.phase * 0.71 + index * 1.73)
                    * (active ? 1.75 : 1.35)
                : Math.sin(index * 1.73 + 0.73) * 0.45
        readonly property real activeGrow: active ? 7 : 0

        readonly property real centerX: root.width / 2
            + cosAngle * (root.orbitRadiusX + wave)
            + (ribbon ? tangentX * tangential : 0)
        readonly property real centerY: root.height / 2
            + sinAngle * (root.orbitRadiusY + (ribbon ? wave * 0.56 : 0))
            + (ribbon ? tangentY * tangential : 0)

        readonly property real width: !enabledBody ? 0
            : ribbon
                ? root.baseThickness + thicknessPulse
                    + root.ribbonSpan * Math.abs(tangentX)
                : root.nodeWidth + activeGrow + breathing
        readonly property real height: !enabledBody ? 0
            : ribbon
                ? root.baseThickness + thicknessPulse
                    + root.ribbonSpan * Math.abs(tangentY)
                : root.nodeHeight + activeGrow * 1.12 + breathing * 0.72
        readonly property real x: centerX - width / 2
        readonly property real y: centerY - height / 2
        readonly property real radius: Math.min(width, height) / 2
        readonly property real fuse: active
            ? root.fuseDepth + 5 : root.fuseDepth
        readonly property string shapeId:
            (ribbon ? "ribbon-" : "hour-") + index
        readonly property var joins: ribbon
            ? ["ribbon-" + ((index + root.ribbonCount - 1)
                % root.ribbonCount)]
            : ["ribbon-" + Number(root.hourRibbonIndices[index] ?? 0)]
    }

    LiquidBody { id: ribbon0; ribbon: true; index: 0 }
    LiquidBody { id: ribbon1; ribbon: true; index: 1 }
    LiquidBody { id: ribbon2; ribbon: true; index: 2 }
    LiquidBody { id: ribbon3; ribbon: true; index: 3 }
    LiquidBody { id: ribbon4; ribbon: true; index: 4 }
    LiquidBody { id: ribbon5; ribbon: true; index: 5 }
    LiquidBody { id: ribbon6; ribbon: true; index: 6 }
    LiquidBody { id: ribbon7; ribbon: true; index: 7 }
    LiquidBody { id: ribbon8; ribbon: true; index: 8 }
    LiquidBody { id: ribbon9; ribbon: true; index: 9 }
    LiquidBody { id: ribbon10; ribbon: true; index: 10 }
    LiquidBody { id: ribbon11; ribbon: true; index: 11 }

    LiquidBody { id: hour0; ribbon: false; index: 0 }
    LiquidBody { id: hour1; ribbon: false; index: 1 }
    LiquidBody { id: hour2; ribbon: false; index: 2 }
    LiquidBody { id: hour3; ribbon: false; index: 3 }
    LiquidBody { id: hour4; ribbon: false; index: 4 }
    LiquidBody { id: hour5; ribbon: false; index: 5 }
    LiquidBody { id: hour6; ribbon: false; index: 6 }
    LiquidBody { id: hour7; ribbon: false; index: 7 }

    readonly property var liquidShapes: [
        ribbon0, ribbon1, ribbon2, ribbon3,
        ribbon4, ribbon5, ribbon6, ribbon7,
        ribbon8, ribon9, ribbon10, ribbon11,
        hour0, hour1, hour2, hour3,
        hour4, hour5, hour6, hour7
    ]

    ConnectedSurfaceIrisField {
        id: field
        anchors.fill: parent
        paintBounds: Qt.rect(0, 0, root.width, root.height)
        shapes: root.liquidShapes
        tint: root.fieldColor
        rimColor: root.edgeColor
        rimWidth: 1.15
        smoothing: root.fuseDepth
        visible: root.hourAngles.length > 0
    }
}
