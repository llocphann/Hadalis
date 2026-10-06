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
    // Top/bottom bands must include the rounded-corner reach. Once those
    // corner zones are removed, the middle left/right bands see only straight
    // edges and need no extra radius allowance.
    readonly property real topBandExtent: Math.ceil(
        Math.max(0, topInset) + Math.max(0, radius) + safeReach)
    readonly property real bottomBandExtent: Math.ceil(
        Math.max(0, bottomInset) + Math.max(0, radius) + safeReach)
    readonly property real leftBandExtent: Math.ceil(
        Math.max(0, leftInset) + safeReach)
    readonly property real rightBandExtent: Math.ceil(
        Math.max(0, rightInset) + safeReach)

    readonly property real topBandHeight: Math.min(height, topBandExtent)
    readonly property real bottomBandHeight: Math.min(
        Math.max(0, height - topBandHeight), bottomBandExtent)
    readonly property real middleY: topBandHeight
    readonly property real middleHeight: Math.max(
        0, height - topBandHeight - bottomBandHeight)
    readonly property real leftBandWidth: Math.min(width, leftBandExtent)
    readonly property real rightBandWidth: Math.min(
        Math.max(0, width - leftBandWidth), rightBandExtent)

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
