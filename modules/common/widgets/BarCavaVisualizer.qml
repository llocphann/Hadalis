pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common
import qs.services

// Bounded-raster renderer for the full-width Bar audio spectrum.
//
// A full-width threaded Canvas was the original CPU hotspot, while a large
// Repeater graph moved the cost into QQml property fan-out. Keep one proven
// CavaSpectrum surface, but raster it at a bounded horizontal resolution and
// let the scene graph scale that texture to the Bar width.
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

    // Wave geometry remains visually smooth at this texture width while
    // rasterizing only a fraction of a typical 1080p/1440p/4K Bar.
    property int waveRasterWidthCap: 512
    property int minimumRasterWidth: 384

    readonly property real _barRasterMinimum: Math.ceil(
        Math.max(1, root.width) * 3 / Math.max(3, root.pixelsPerBar))
    readonly property real _targetRasterWidth: root.visualizerType === "bars"
        ? Math.max(root.minimumRasterWidth, root._barRasterMinimum)
        : root.waveRasterWidthCap
    readonly property real _rasterWidth: Math.max(1,
        Math.min(Math.max(1, root.width), root._targetRasterWidth))
    readonly property real _xScale: Math.max(1,
        Math.max(1, root.width) / root._rasterWidth)
    readonly property real _edgeTaperScale:
        0.75 + Math.max(0, Math.min(1, root.edgeSoftness)) * 1.25

    visible: spectrum.visible

    CavaSpectrum {
        id: spectrum

        width: root._rasterWidth
        height: root.height
        transform: Scale {
            origin.x: 0
            origin.y: 0
            xScale: root._xScale
            yScale: 1
        }

        // Canvas stays threaded, but its backing image is bounded rather than
        // matching the entire monitor width.
        threadedRendering: true
        smooth: true

        active: root.active
        points: active ? root.points : []
        normalizationCeiling: root.normalizationCeiling
        visualizerType: root.visualizerType
        spectrumOpacity: root.spectrumOpacity
        fillRatio: root.fillRatio
        spectrumColor: root.spectrumColor
        spectrumColors: root.spectrumColors
        barsOrigin: root.barsOrigin

        // Preserve final on-screen spacing after the horizontal scene-graph
        // scale. CavaSpectrum clamps pitch to 3 px, so bars mode raises the
        // raster width when necessary instead of silently dropping bands.
        pixelsPerBar: Math.max(3, root.pixelsPerBar / root._xScale)
        barSpacing: Math.max(0, root.barSpacing / root._xScale)
        barRadius: Math.max(0, root.barRadius / root._xScale)
        barMinHeight: root.barMinHeight

        smoothing: root.smoothing
        waveMode: root.waveMode
        waveOutlineEnabled: false
        lineWidth: root.lineWidth
        edgeInset: Math.max(0, root.edgeInset / root._xScale)
        edgeSoftness: root.edgeSoftness
        frequencyProfile: root.frequencyProfile
        accentStrength: root.accentStrength
        mirroredStereo: root.mirroredStereo

        // BarBackground already clips the final scaled texture to the actual
        // panel corners. Keep Canvas clipping rectangular and preserve only the
        // edge taper in scaled coordinates, avoiding distorted elliptical
        // corner paths under a non-uniform X transform.
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: 0
        bottomRightRadius: 0
        startTaper: Math.max(0,
            Math.max(root.topLeftRadius, root.bottomLeftRadius)
                * root._edgeTaperScale / root._xScale)
        endTaper: Math.max(0,
            Math.max(root.topRightRadius, root.bottomRightRadius)
                * root._edgeTaperScale / root._xScale)
    }
}
