import QtQuick

Item {
    id: root

    required property string outputName

    property bool hostEnabled: true
    property real slotSpacing: 8
    property real segmentSpacing: slotSpacing
    property real topInset: 0
    property real bottomInset: 0
    property real leftInset: 0
    property real rightInset: 0

    readonly property rect outputRect: Qt.rect(0, 0, width, height)
    readonly property bool configValid: PerimeterConfig.validate(outputName)
    readonly property Item topStartSlot: topStart
    readonly property Item topCenterSlot: topCenter
    readonly property Item topEndSlot: topEnd
    readonly property Item leftCenterSlot: leftCenter
    readonly property Item rightCenterSlot: rightCenter
    readonly property Item bottomStartSlot: bottomStart
    readonly property Item bottomCenterSlot: bottomCenter
    readonly property Item bottomEndSlot: bottomEnd

    readonly property bool topStartOccupied: root._occupied(topStart)
    readonly property bool topCenterOccupied: root._occupied(topCenter)
    readonly property bool topEndOccupied: root._occupied(topEnd)
    readonly property bool leftCenterOccupied: root._occupied(leftCenter)
    readonly property bool rightCenterOccupied: root._occupied(rightCenter)
    readonly property bool bottomStartOccupied: root._occupied(bottomStart)
    readonly property bool bottomCenterOccupied: root._occupied(bottomCenter)
    readonly property bool bottomEndOccupied: root._occupied(bottomEnd)

    // Center slots are positional invariants. Core reports pressure/collision
    // instead of silently sliding them away from the output center.
    readonly property real topCenterDesiredX: (width - topCenter.width) / 2
    readonly property real topCenterMinX: topStartOccupied
        ? topStart.x + topStart.width + segmentSpacing : leftInset
    readonly property real topCenterMaxX: topEndOccupied
        ? topEnd.x - topCenter.width - segmentSpacing
        : width - rightInset - topCenter.width
    readonly property bool topCenterFits: !topCenterOccupied
        || (topCenterDesiredX >= topCenterMinX
            && topCenterDesiredX <= topCenterMaxX)
    readonly property bool topEdgeSegmentsFit: !topStartOccupied || !topEndOccupied
        || topStart.x + topStart.width + segmentSpacing <= topEnd.x
    readonly property bool topEdgeOverflowsOutput:
        root._overflowsOutput(topStart)
        || root._overflowsOutput(topCenter)
        || root._overflowsOutput(topEnd)

    readonly property real bottomCenterDesiredX: (width - bottomCenter.width) / 2
    readonly property real bottomCenterMinX: bottomStartOccupied
        ? bottomStart.x + bottomStart.width + segmentSpacing : leftInset
    readonly property real bottomCenterMaxX: bottomEndOccupied
        ? bottomEnd.x - bottomCenter.width - segmentSpacing
        : width - rightInset - bottomCenter.width
    readonly property bool bottomCenterFits: !bottomCenterOccupied
        || (bottomCenterDesiredX >= bottomCenterMinX
            && bottomCenterDesiredX <= bottomCenterMaxX)
    readonly property bool bottomEdgeSegmentsFit: !bottomStartOccupied || !bottomEndOccupied
        || bottomStart.x + bottomStart.width + segmentSpacing <= bottomEnd.x
    readonly property bool bottomEdgeOverflowsOutput:
        root._overflowsOutput(bottomStart)
        || root._overflowsOutput(bottomCenter)
        || root._overflowsOutput(bottomEnd)

    // Top and bottom hosts can overlap on short outputs without either host
    // leaving output bounds. Report that pressure instead of silently accepting
    // intersecting edge chrome at natural sizes.
    readonly property bool topBottomOverlap:
        root._itemsOverlap(topStart, bottomStart)
        || root._itemsOverlap(topStart, bottomCenter)
        || root._itemsOverlap(topStart, bottomEnd)
        || root._itemsOverlap(topCenter, bottomStart)
        || root._itemsOverlap(topCenter, bottomCenter)
        || root._itemsOverlap(topCenter, bottomEnd)
        || root._itemsOverlap(topEnd, bottomStart)
        || root._itemsOverlap(topEnd, bottomCenter)
        || root._itemsOverlap(topEnd, bottomEnd)

    readonly property bool topCollision: topEdgeOverflowsOutput
        || !topEdgeSegmentsFit || !topCenterFits || topBottomOverlap
    readonly property bool bottomCollision: bottomEdgeOverflowsOutput
        || !bottomEdgeSegmentsFit || !bottomCenterFits || topBottomOverlap

    // Side slots stay truly centered at their natural size. Core never shrinks or
    // shifts them; these flags only expose overload/collision state to consumers.
    readonly property bool leftCenterOverflowsOutput: root._overflowsOutput(leftCenter)
    readonly property bool rightCenterOverflowsOutput: root._overflowsOutput(rightCenter)
    readonly property bool sideSlotsOverlap: root._itemsOverlap(leftCenter, rightCenter)
    readonly property bool leftCollision: leftCenterOverflowsOutput
        || sideSlotsOverlap
        || root._itemsOverlap(leftCenter, topStart)
        || root._itemsOverlap(leftCenter, topCenter)
        || root._itemsOverlap(leftCenter, topEnd)
        || root._itemsOverlap(leftCenter, bottomStart)
        || root._itemsOverlap(leftCenter, bottomCenter)
        || root._itemsOverlap(leftCenter, bottomEnd)
    readonly property bool rightCollision: rightCenterOverflowsOutput
        || sideSlotsOverlap
        || root._itemsOverlap(rightCenter, topStart)
        || root._itemsOverlap(rightCenter, topCenter)
        || root._itemsOverlap(rightCenter, topEnd)
        || root._itemsOverlap(rightCenter, bottomStart)
        || root._itemsOverlap(rightCenter, bottomCenter)
        || root._itemsOverlap(rightCenter, bottomEnd)

    function _occupied(item) {
        return item !== null && item.visible && item.width > 0 && item.height > 0
    }

    function _overflowsOutput(item) {
        if (!root._occupied(item))
            return false
        return item.x < 0 || item.y < 0
            || item.x + item.width > root.width
            || item.y + item.height > root.height
    }

    function _itemsOverlap(a, b) {
        if (!root._occupied(a) || !root._occupied(b))
            return false
        return a.x < b.x + b.width
            && a.x + a.width > b.x
            && a.y < b.y + b.height
            && a.y + a.height > b.y
    }

    function slotHost(slotId) {
        switch (String(slotId ?? "")) {
        case "top.start": return topStart
        case "top.center": return topCenter
        case "top.end": return topEnd
        case "left.center": return leftCenter
        case "right.center": return rightCenter
        case "bottom.start": return bottomStart
        case "bottom.center": return bottomCenter
        case "bottom.end": return bottomEnd
        default: return null
        }
    }

    PerimeterSlotHost {
        id: topStart
        outputName: root.outputName
        slotId: "top.start"
        hostEnabled: root.hostEnabled && root.configValid
        spacing: root.slotSpacing
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: root.topInset
        anchors.leftMargin: root.leftInset
    }

    PerimeterSlotHost {
        id: topCenter
        outputName: root.outputName
        slotId: "top.center"
        hostEnabled: root.hostEnabled && root.configValid
        spacing: root.slotSpacing
        x: root.topCenterDesiredX
        anchors.top: parent.top
        anchors.topMargin: root.topInset
    }

    PerimeterSlotHost {
        id: topEnd
        outputName: root.outputName
        slotId: "top.end"
        hostEnabled: root.hostEnabled && root.configValid
        spacing: root.slotSpacing
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: root.topInset
        anchors.rightMargin: root.rightInset
    }

    // Side slots intentionally keep their natural content size and are only
    // vertically centered. No maximum height is imposed by core.
    PerimeterSlotHost {
        id: leftCenter
        outputName: root.outputName
        slotId: "left.center"
        hostEnabled: root.hostEnabled && root.configValid
        spacing: root.slotSpacing
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: root.leftInset
    }

    PerimeterSlotHost {
        id: rightCenter
        outputName: root.outputName
        slotId: "right.center"
        hostEnabled: root.hostEnabled && root.configValid
        spacing: root.slotSpacing
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: root.rightInset
    }

    PerimeterSlotHost {
        id: bottomStart
        outputName: root.outputName
        slotId: "bottom.start"
        hostEnabled: root.hostEnabled && root.configValid
        spacing: root.slotSpacing
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.bottomMargin: root.bottomInset
        anchors.leftMargin: root.leftInset
    }

    PerimeterSlotHost {
        id: bottomCenter
        outputName: root.outputName
        slotId: "bottom.center"
        hostEnabled: root.hostEnabled && root.configValid
        spacing: root.slotSpacing
        x: root.bottomCenterDesiredX
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.bottomInset
    }

    PerimeterSlotHost {
        id: bottomEnd
        outputName: root.outputName
        slotId: "bottom.end"
        hostEnabled: root.hostEnabled && root.configValid
        spacing: root.slotSpacing
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.bottomMargin: root.bottomInset
        anchors.rightMargin: root.rightInset
    }
}
