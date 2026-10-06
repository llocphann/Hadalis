import QtQuick

// Healthy physical Screen Edge painter.
//
// Four disjoint ShaderEffect tiles cover only the perimeter reach that can
// produce non-zero pixels. The centre rectangle is guaranteed to satisfy the
// fragment shader's deep-interior transparent predicate and is never rasterized.
Item {
    id: root

    required property real leftInset
    required property real topInset
    required property real rightInset
    required property real bottomInset
    required property real radius
    required property color edgeColor
    required property color elevationColor
    required property real elevationSize
    required property bool elevationEnabled

    readonly property real shadowReach:
        elevationEnabled ? Math.max(0, elevationSize) : 0
    readonly property real safeReach: Math.max(shadowReach, 2)
    readonly property real bandExtent: Math.ceil(
        Math.max(leftInset, topInset, rightInset, bottomInset)
        + Math.max(0, radius)
        + safeReach
        + 2)

    readonly property real topBandHeight: Math.min(height, bandExtent)
    readonly property real bottomBandHeight: Math.min(
        Math.max(0, height - topBandHeight), bandExtent)
    readonly property real middleY: topBandHeight
    readonly property real middleHeight: Math.max(
        0, height - topBandHeight - bottomBandHeight)
    readonly property real leftBandWidth: Math.min(width, bandExtent)
    readonly property real rightBandWidth: Math.min(
        Math.max(0, width - leftBandWidth), bandExtent)

    readonly property vector4d viewportUniform:
        Qt.vector4d(width, height, 0, 0)
    readonly property vector4d insetsUniform:
        Qt.vector4d(leftInset, topInset, rightInset, bottomInset)
    readonly property color frameColorUniform: edgeColor
    readonly property color shadowColorUniform: elevationEnabled
        ? elevationColor : Qt.rgba(0, 0, 0, 0)
    readonly property vector4d paramsUniform:
        Qt.vector4d(radius, shadowReach, 0.75, 0)

    readonly property bool shaderError:
        topBand.status === ShaderEffect.Error
        || bottomBand.status === ShaderEffect.Error
        || leftBand.status === ShaderEffect.Error
        || rightBand.status === ShaderEffect.Error

    component Band: ShaderEffect {
        blending: true
        property vector4d viewport: root.viewportUniform
        property vector4d insets: root.insetsUniform
        property color frameColor: root.frameColorUniform
        property color shadowColor: root.shadowColorUniform
        property vector4d params: root.paramsUniform
        property vector4d tileRect: Qt.vector4d(x, y, width, height)
        fragmentShader: Qt.resolvedUrl("ScreenEdgeField.frag.qsb")
    }

    Band {
        id: topBand
        x: 0
        y: 0
        width: root.width
        height: root.topBandHeight
    }

    Band {
        id: bottomBand
        x: 0
        y: root.height - root.bottomBandHeight
        width: root.width
        height: root.bottomBandHeight
    }

    Band {
        id: leftBand
        x: 0
        y: root.middleY
        width: root.leftBandWidth
        height: root.middleHeight
    }

    Band {
        id: rightBand
        x: root.width - root.rightBandWidth
        y: root.middleY
        width: root.rightBandWidth
        height: root.middleHeight
    }
}
