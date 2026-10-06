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
    readonly property real radiusReach: Math.max(0, radius)

    // Straight-edge tiles need only inset + shadow/AA reach. Exactly one axis
    // also carries the rounded-corner reach; choose the cheaper of the two
    // four-tile partitions for the current output geometry.
    readonly property real topShallowExtent:
        Math.ceil(Math.max(0, topInset) + safeReach)
    readonly property real bottomShallowExtent:
        Math.ceil(Math.max(0, bottomInset) + safeReach)
    readonly property real leftShallowExtent:
        Math.ceil(Math.max(0, leftInset) + safeReach)
    readonly property real rightShallowExtent:
        Math.ceil(Math.max(0, rightInset) + safeReach)
    readonly property real topDeepExtent:
        Math.ceil(Math.max(0, topInset) + radiusReach + safeReach)
    readonly property real bottomDeepExtent:
        Math.ceil(Math.max(0, bottomInset) + radiusReach + safeReach)
    readonly property real leftDeepExtent:
        Math.ceil(Math.max(0, leftInset) + radiusReach + safeReach)
    readonly property real rightDeepExtent:
        Math.ceil(Math.max(0, rightInset) + radiusReach + safeReach)

    readonly property real horizontalTopHeight:
        Math.min(height, topDeepExtent)
    readonly property real horizontalBottomHeight: Math.min(
        Math.max(0, height - horizontalTopHeight), bottomDeepExtent)
    readonly property real horizontalMiddleHeight: Math.max(
        0, height - horizontalTopHeight - horizontalBottomHeight)
    readonly property real horizontalLeftWidth:
        Math.min(width, leftShallowExtent)
    readonly property real horizontalRightWidth: Math.min(
        Math.max(0, width - horizontalLeftWidth), rightShallowExtent)
    readonly property real horizontalArea:
        width * (horizontalTopHeight + horizontalBottomHeight)
        + horizontalMiddleHeight
            * (horizontalLeftWidth + horizontalRightWidth)

    readonly property real verticalLeftWidth:
        Math.min(width, leftDeepExtent)
    readonly property real verticalRightWidth: Math.min(
        Math.max(0, width - verticalLeftWidth), rightDeepExtent)
    readonly property real verticalMiddleWidth: Math.max(
        0, width - verticalLeftWidth - verticalRightWidth)
    readonly property real verticalTopHeight:
        Math.min(height, topShallowExtent)
    readonly property real verticalBottomHeight: Math.min(
        Math.max(0, height - verticalTopHeight), bottomShallowExtent)
    readonly property real verticalArea:
        height * (verticalLeftWidth + verticalRightWidth)
        + verticalMiddleWidth * (verticalTopHeight + verticalBottomHeight)

    readonly property bool horizontalCornerBands:
        horizontalArea <= verticalArea

    readonly property real topBandX:
        horizontalCornerBands ? 0 : verticalLeftWidth
    readonly property real topBandWidth:
        horizontalCornerBands ? width : verticalMiddleWidth
    readonly property real topBandHeight:
        horizontalCornerBands ? horizontalTopHeight : verticalTopHeight

    readonly property real bottomBandX:
        horizontalCornerBands ? 0 : verticalLeftWidth
    readonly property real bottomBandWidth:
        horizontalCornerBands ? width : verticalMiddleWidth
    readonly property real bottomBandHeight:
        horizontalCornerBands ? horizontalBottomHeight : verticalBottomHeight

    readonly property real leftBandY:
        horizontalCornerBands ? horizontalTopHeight : 0
    readonly property real leftBandWidth:
        horizontalCornerBands ? horizontalLeftWidth : verticalLeftWidth
    readonly property real leftBandHeight:
        horizontalCornerBands ? horizontalMiddleHeight : height

    readonly property real rightBandY:
        horizontalCornerBands ? horizontalTopHeight : 0
    readonly property real rightBandWidth:
        horizontalCornerBands ? horizontalRightWidth : verticalRightWidth
    readonly property real rightBandHeight:
        horizontalCornerBands ? horizontalMiddleHeight : height

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
        x: root.topBandX
        y: 0
        width: root.topBandWidth
        height: root.topBandHeight
    }

    Band {
        id: bottomBand
        x: root.bottomBandX
        y: root.height - root.bottomBandHeight
        width: root.bottomBandWidth
        height: root.bottomBandHeight
    }

    Band {
        id: leftBand
        x: 0
        y: root.leftBandY
        width: root.leftBandWidth
        height: root.leftBandHeight
    }

    Band {
        id: rightBand
        x: root.width - root.rightBandWidth
        y: root.rightBandY
        width: root.rightBandWidth
        height: root.rightBandHeight
    }
}
