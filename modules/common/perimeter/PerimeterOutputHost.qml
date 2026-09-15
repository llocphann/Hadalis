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

    readonly property real topCenterDesiredX: (width - topCenter.width) / 2
    readonly property real topCenterMinX: topStartOccupied
        ? topStart.x + topStart.width + segmentSpacing : leftInset
    readonly property real topCenterMaxX: topEndOccupied
        ? topEnd.x - topCenter.width - segmentSpacing
        : width - rightInset - topCenter.width
    readonly property bool topCenterFits: !topCenterOccupied
        || topCenterMinX <= topCenterMaxX
    readonly property bool topEdgeSegmentsFit: !topStartOccupied || !topEndOccupied
        || topStart.x + topStart.width + segmentSpacing <= topEnd.x
    readonly property bool topCollision: !topEdgeSegmentsFit || !topCenterFits

    readonly property real bottomCenterDesiredX: (width - bottomCenter.width) / 2
    readonly property real bottomCenterMinX: bottomStartOccupied
        ? bottomStart.x + bottomStart.width + segmentSpacing : leftInset
    readonly property real bottomCenterMaxX: bottomEndOccupied
        ? bottomEnd.x - bottomCenter.width - segmentSpacing
        : width - rightInset - bottomCenter.width
    readonly property bool bottomCenterFits: !bottomCenterOccupied
        || bottomCenterMinX <= bottomCenterMaxX
    readonly property bool bottomEdgeSegmentsFit: !bottomStartOccupied || !bottomEndOccupied
        || bottomStart.x + bottomStart.width + segmentSpacing <= bottomEnd.x
    readonly property bool bottomCollision: !bottomEdgeSegmentsFit || !bottomCenterFits

    // Side slots stay truly centered at their natural size. Core never shrinks or
    // shifts them; these flags only expose overload/collision state to consumers.
    readonly property bool leftCenterOverflowsOutput: leftCenterOccupied
        && (leftCenter.y < 0 || leftCenter.y + leftCenter.height > height)
    readonly property bool rightCenterOverflowsOutput: rightCenterOccupied
        && (rightCenter.y < 0 || rightCenter.y + rightCenter.height > height)
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

    function _clamp(value, minimum, maximum) {
        return Math.max(minimum, Math.min(maximum, value))
    }

    function _occupied(item) {
        return item !== null && item.visible && item.width > 0 && item.height > 0
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
        x: root.topCenterFits
            ? root._clamp(root.topCenterDesiredX,
                root.topCenterMinX, root.topCenterMaxX)
            : root.topCenterDesiredX
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
        x: root.bottomCenterFits
            ? root._clamp(root.bottomCenterDesiredX,
                root.bottomCenterMinX, root.bottomCenterMaxX)
            : root.bottomCenterDesiredX
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
