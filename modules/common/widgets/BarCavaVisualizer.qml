pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import qs.modules.common
import qs.services

// Scene-graph renderer for the full-width Bar audio spectrum.
//
// CavaSpectrum is Canvas-based and therefore rasterizes the complete Bar surface
// in QQuickContext2D on every audio frame. This component keeps the same shared
// CAVA data/lifecycle but renders bars as Rectangle scene-graph nodes and waves
// as Qt Quick Shapes, avoiding the hot software-raster Canvas path.
Item {
    id: root

    property var points: []
    property bool active: false
    property string visualizerType: "bars"
    property real normalizationCeiling: 1000
    property real fillRatio: 0.6
    property real spectrumOpacity: 0.35
    property color spectrumColor: Appearance.colors.colPrimary
    property var spectrumColors: CavaTheme.visualizerColors
    property real pixelsPerBar: 12
    property real barSpacing: 2
    property real barRadius: 2
    property real barMinHeight: 1
    property string barsOrigin: "bottom"
    property int smoothing: 2
    property string waveMode: "fill"
    property real lineWidth: 2
    property real edgeInset: 0
    property real topLeftRadius: 0
    property real topRightRadius: 0
    property real bottomLeftRadius: 0
    property real bottomRightRadius: 0
    property real edgeSoftness: 0.28
    property string frequencyProfile: "flat"
    property real accentStrength: 0.7
    property bool mirroredStereo: Config.options?.appearance?.cava?.stereo ?? true

    readonly property real _innerWidth: Math.max(1, width - edgeInset * 2)
    readonly property int _barCount: root.active && root.visualizerType === "bars"
        ? Math.max(4, Math.floor(
            (root._innerWidth + Math.max(0, root.barSpacing))
            / Math.max(3, root.pixelsPerBar)))
        : 0
    // Frame geometry is published once per event-loop turn. CavaService updates
    // points and normalizationCeiling separately; reactive binding chains would
    // otherwise rebuild the same path more than once for one audio frame.
    property var _barLevels: []
    property var _wavePath: []
    property var _selectedScratch: []
    property var _smoothScratch: []
    property bool _frameRebuildQueued: false

    visible: root.opacity > 0.001 || root.active
    opacity: root.active ? Math.max(0, Math.min(1, root.spectrumOpacity)) : 0

    Behavior on opacity {
        enabled: Appearance.animationsEnabled
        NumberAnimation {
            duration: Appearance.calcEffectiveDuration(root.active ? 180 : 480)
            easing.type: root.active ? Easing.OutCubic : Easing.InOutCubic
        }
    }

    function _profileWeight(position): real {
        const x = Math.max(0, Math.min(1, position))
        if (root.frequencyProfile === "bass")
            return 0.44 + 1.86 * Math.exp(-4.2 * x)
        if (root.frequencyProfile === "warm")
            return 1.82 - 1.08 * x
        if (root.frequencyProfile === "vocal") {
            const distance = (x - 0.46) / 0.17
            return 0.48 + 1.72 * Math.exp(-distance * distance)
        }
        if (root.frequencyProfile === "treble")
            return 0.44 + 1.86 * Math.pow(x, 1.75)
        if (root.frequencyProfile === "smile")
            return 0.52 + 1.56 * Math.pow(Math.abs(x - 0.5) * 2, 1.45)
        return 1
    }

    function _processPoints(): var {
        if (!root.active)
            return []
        const source = root.points ?? []
        const count = source.length ?? 0
        if (count === 0)
            return []

        const selected = root._selectedScratch
        selected.length = count
        const strength = Math.max(0, Math.min(1, root.accentStrength))
        const applyProfile = strength > 0 && root.frequencyProfile !== "flat"
        for (let i = 0; i < count; ++i) {
            let value = Number(source[i]) || 0
            if (applyProfile) {
                const domain = count > 1 ? i / (count - 1) : 0.5
                const frequency = root.mirroredStereo
                    ? Math.abs(domain * 2 - 1) : domain
                const weight = root._profileWeight(frequency)
                value *= 1 + (weight - 1) * strength
            }
            selected[i] = value
        }

        const radius = Math.max(0, Math.round(root.smoothing))
        if (radius === 0 || count < 3)
            return selected

        const smoothed = root._smoothScratch
        smoothed.length = count
        let start = 0
        let end = Math.min(count - 1, radius)
        let sum = 0
        for (let i = start; i <= end; ++i)
            sum += selected[i]
        for (let i = 0; i < count; ++i) {
            const nextStart = Math.max(0, i - radius)
            const nextEnd = Math.min(count - 1, i + radius)
            while (start < nextStart)
                sum -= selected[start++]
            while (end < nextEnd)
                sum += selected[++end]
            smoothed[i] = sum / Math.max(1, end - start + 1)
        }
        return smoothed
    }

    function _makeBarLevels(source): var {
        const sourceCount = source.length ?? 0
        const count = root._barCount
        if (sourceCount === 0 || count <= 0)
            return []

        const result = new Array(count)
        const ceiling = Math.max(1, root.normalizationCeiling)
        for (let i = 0; i < count; ++i) {
            const from = Math.floor(i * sourceCount / count)
            const to = Math.min(sourceCount,
                Math.max(from + 1, Math.ceil((i + 1) * sourceCount / count)))
            let sum = 0
            let peak = 0
            let samples = 0
            for (let j = from; j < to; ++j) {
                const sample = source[j] || 0
                sum += sample
                peak = Math.max(peak, sample)
                samples++
            }
            const average = samples > 0 ? sum / samples : 0
            result[i] = Math.max(0, Math.min(1,
                (average * 0.72 + peak * 0.28) / ceiling))
        }
        return result
    }

    function _cornerInset(x, radius, fromLeft): real {
        if (!(radius > 0))
            return 0
        let distance = 0
        if (fromLeft) {
            if (x >= radius)
                return 0
            distance = radius - Math.max(0, x)
        } else {
            if (x <= root.width - radius)
                return 0
            distance = Math.max(0, x - (root.width - radius))
        }
        return radius - Math.sqrt(Math.max(
            0, radius * radius - distance * distance))
    }

    function _edgeFactor(x): real {
        const scale = 0.75 + Math.max(0, Math.min(1, root.edgeSoftness)) * 1.25
        const startTaper = Math.max(
            root.topLeftRadius, root.bottomLeftRadius) * scale
        const endTaper = Math.max(
            root.topRightRadius, root.bottomRightRadius) * scale
        const x0 = Math.max(0, root.edgeInset)
        const x1 = Math.max(x0 + 1, root.width - root.edgeInset)
        let factor = 1
        if (startTaper > 0) {
            const t = Math.max(0, Math.min(1, (x - x0) / startTaper))
            factor *= t * t * (3 - 2 * t)
        }
        if (endTaper > 0) {
            const t = Math.max(0, Math.min(1, (x1 - x) / endTaper))
            factor *= t * t * (3 - 2 * t)
        }
        return Math.max(0, Math.min(1, factor))
    }

    function _topAt(x): real {
        return Math.max(
            root._cornerInset(x, root.topLeftRadius, true),
            root._cornerInset(x, root.topRightRadius, false))
    }

    function _bottomAt(x): real {
        const top = root._topAt(x)
        const bottomInset = Math.max(
            root._cornerInset(x, root.bottomLeftRadius, true),
            root._cornerInset(x, root.bottomRightRadius, false))
        return Math.max(top, root.height - bottomInset)
    }

    function _sampleAt(source, position): real {
        const count = source.length ?? 0
        if (count === 0)
            return 0
        if (count === 1)
            return source[0] || 0
        const p = Math.max(0, Math.min(count - 1, position * (count - 1)))
        const low = Math.floor(p)
        const high = Math.min(count - 1, low + 1)
        const fraction = p - low
        return (source[low] || 0) * (1 - fraction)
            + (source[high] || 0) * fraction
    }

    function _makeWavePath(source): var {
        const sourceCount = source.length ?? 0
        if (!root.active || sourceCount < 2 || !(root.width > 0) || !(root.height > 0))
            return []

        const x0 = Math.max(0, root.edgeInset)
        const x1 = Math.max(x0 + 1, root.width - root.edgeInset)
        const span = Math.max(1, x1 - x0)
        const count = Math.max(2, Math.min(sourceCount,
            Math.round(span / Math.max(4, root.pixelsPerBar))))
        const ceiling = Math.max(1, root.normalizationCeiling)
        const fill = Math.max(0.1, Math.min(1, root.fillRatio))
        const ribbon = root.waveMode === "ribbon" || root.barsOrigin === "mirror"
        const primary = new Array(count)
        const secondary = ribbon ? new Array(count) : null
        const baseline = !ribbon && root.waveMode !== "line"
            ? new Array(count) : null

        for (let i = 0; i < count; ++i) {
            const ratio = count > 1 ? i / (count - 1) : 0
            const x = x0 + ratio * span
            const top = root._topAt(x)
            const bottom = root._bottomAt(x)
            const center = (top + bottom) / 2
            const edge = root._edgeFactor(x)
            const level = Math.max(0, Math.min(1,
                root._sampleAt(source, ratio) / ceiling)) * edge

            let y = bottom
            let baseY = bottom
            if (ribbon) {
                const half = level * Math.max(0, (bottom - top) / 2) * fill
                primary[i] = Qt.point(x, center - half)
                secondary[i] = Qt.point(x, center + half)
                continue
            } else if (root.barsOrigin === "top") {
                y = top + level * Math.max(0, bottom - top) * fill
                baseY = top
            } else if (root.barsOrigin === "center") {
                y = center - level * Math.max(0, center - top) * fill
                baseY = center
            } else {
                y = bottom - level * Math.max(0, bottom - top) * fill
                baseY = bottom
            }
            primary[i] = Qt.point(x, y)
            if (baseline)
                baseline[i] = Qt.point(x, baseY)
        }

        if (root.waveMode === "line")
            return primary

        const polygon = primary.slice()
        const lower = secondary ?? baseline
        for (let i = lower.length - 1; i >= 0; --i)
            polygon.push(lower[i])
        return polygon
    }

    function _rebuildFrameGeometry(): void {
        if (!root.active) {
            if (root._barLevels.length > 0)
                root._barLevels = []
            if (root._wavePath.length > 0)
                root._wavePath = []
            return
        }

        const processed = root._processPoints()
        if (root.visualizerType === "wave") {
            root._barLevels = []
            root._wavePath = root._makeWavePath(processed)
        } else {
            root._wavePath = []
            root._barLevels = root._makeBarLevels(processed)
        }
    }

    function _queueFrameGeometry(): void {
        if (root._frameRebuildQueued)
            return
        root._frameRebuildQueued = true
        Qt.callLater(() => {
            root._frameRebuildQueued = false
            root._rebuildFrameGeometry()
        })
    }

    onPointsChanged: root._queueFrameGeometry()
    onNormalizationCeilingChanged: root._queueFrameGeometry()
    onActiveChanged: root._queueFrameGeometry()
    onVisualizerTypeChanged: root._queueFrameGeometry()
    onFillRatioChanged: root._queueFrameGeometry()
    onPixelsPerBarChanged: root._queueFrameGeometry()
    onBarSpacingChanged: root._queueFrameGeometry()
    onBarsOriginChanged: root._queueFrameGeometry()
    onSmoothingChanged: root._queueFrameGeometry()
    onWaveModeChanged: root._queueFrameGeometry()
    onEdgeInsetChanged: root._queueFrameGeometry()
    onTopLeftRadiusChanged: root._queueFrameGeometry()
    onTopRightRadiusChanged: root._queueFrameGeometry()
    onBottomLeftRadiusChanged: root._queueFrameGeometry()
    onBottomRightRadiusChanged: root._queueFrameGeometry()
    onEdgeSoftnessChanged: root._queueFrameGeometry()
    onFrequencyProfileChanged: root._queueFrameGeometry()
    onAccentStrengthChanged: root._queueFrameGeometry()
    onMirroredStereoChanged: root._queueFrameGeometry()
    onWidthChanged: root._queueFrameGeometry()
    onHeightChanged: root._queueFrameGeometry()
    Component.onCompleted: root._queueFrameGeometry()

    function _paletteColor(position): color {
        const palette = root.spectrumColors ?? []
        const count = palette.length ?? 0
        if (count === 0)
            return root.spectrumColor
        if (count === 1)
            return palette[0]

        const p = Math.max(0, Math.min(1, position)) * (count - 1)
        const low = Math.floor(p)
        const high = Math.min(count - 1, low + 1)
        const t = p - low
        const a = Qt.color(palette[low])
        const b = Qt.color(palette[high])
        if (!a.valid || !b.valid)
            return root.spectrumColor
        return Qt.rgba(
            a.r + (b.r - a.r) * t,
            a.g + (b.g - a.g) * t,
            a.b + (b.b - a.b) * t,
            a.a + (b.a - a.a) * t)
    }

    Repeater {
        model: root.visualizerType === "bars" ? root._barCount : 0

        delegate: Item {
            required property int index

            readonly property int count: Math.max(1, root._barCount)
            readonly property real slot: root._innerWidth / count
            readonly property real barWidth: Math.max(
                1, slot - Math.max(0, root.barSpacing))
            readonly property real centerX: root.edgeInset
                + index * slot + slot / 2
            readonly property real rawLevel:
                Number(root._barLevels[index] ?? 0)
            readonly property real level:
                rawLevel * root._edgeFactor(centerX)
            readonly property real topY: root._topAt(centerX)
            readonly property real bottomY: root._bottomAt(centerX)
            readonly property real centerY: (topY + bottomY) / 2
            readonly property color barColor:
                root._paletteColor(count > 1 ? index / (count - 1) : 0.5)

            x: root.edgeInset + index * slot + (slot - barWidth) / 2
            y: 0
            width: barWidth
            height: root.height
            opacity: 0.5 + rawLevel * 0.5

            Rectangle {
                id: normalBar
                visible: root.barsOrigin !== "mirror"
                width: parent.width
                radius: Math.min(root.barRadius, width / 2, height / 2)
                color: parent.barColor

                readonly property real available: root.barsOrigin === "center"
                    ? Math.max(0, parent.centerY - parent.topY)
                    : Math.max(0, parent.bottomY - parent.topY)
                height: Math.min(available,
                    Math.max(root.barMinHeight * root._edgeFactor(parent.centerX),
                        parent.level * available
                            * Math.max(0.1, Math.min(1, root.fillRatio))))
                y: root.barsOrigin === "top"
                    ? parent.topY
                    : root.barsOrigin === "center"
                        ? parent.centerY - height
                        : parent.bottomY - height
            }

            Rectangle {
                visible: root.barsOrigin === "mirror"
                width: parent.width
                radius: Math.min(root.barRadius, width / 2, height / 2)
                color: parent.barColor
                readonly property real halfAvailable: Math.max(
                    0, (parent.bottomY - parent.topY) / 2 - 0.5)
                readonly property real halfHeight: Math.max(
                    root.barMinHeight * root._edgeFactor(parent.centerX),
                    parent.level * halfAvailable
                        * Math.max(0.1, Math.min(1, root.fillRatio)))
                height: Math.min(halfAvailable, halfHeight)
                y: parent.centerY - height - 0.5
            }

            Rectangle {
                visible: root.barsOrigin === "mirror"
                width: parent.width
                radius: Math.min(root.barRadius, width / 2, height / 2)
                color: parent.barColor
                readonly property real halfAvailable: Math.max(
                    0, (parent.bottomY - parent.topY) / 2 - 0.5)
                readonly property real halfHeight: Math.max(
                    root.barMinHeight * root._edgeFactor(parent.centerX),
                    parent.level * halfAvailable
                        * Math.max(0.1, Math.min(1, root.fillRatio)))
                height: Math.min(halfAvailable, halfHeight)
                y: parent.centerY + 0.5
            }
        }
    }

    Shape {
        id: waveShape
        anchors.fill: parent
        visible: root.visualizerType === "wave"
            && root._wavePath.length >= 2
        asynchronous: false
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            pathHints: ShapePath.PathLinear
            strokeWidth: root.waveMode === "line"
                ? Math.max(1, root.lineWidth) : 0
            strokeColor: root.waveMode === "line"
                ? root._paletteColor(0.5) : "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            fillColor: root.waveMode === "line" ? "transparent" : root.spectrumColor
            fillGradient: root.waveMode === "line" ? null : waveGradient

            PathPolyline {
                path: root._wavePath
            }
        }

        LinearGradient {
            id: waveGradient
            x1: root.edgeInset
            y1: 0
            x2: Math.max(root.edgeInset + 1, root.width - root.edgeInset)
            y2: 0
            GradientStop { position: 0.00; color: root._paletteColor(0.00) }
            GradientStop { position: 0.25; color: root._paletteColor(0.25) }
            GradientStop { position: 0.50; color: root._paletteColor(0.50) }
            GradientStop { position: 0.75; color: root._paletteColor(0.75) }
            GradientStop { position: 1.00; color: root._paletteColor(1.00) }
        }
    }
}
