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

    readonly property real topCenterDesiredX: (width - topCenter.width) / 2
    readonly property real topCenterMinX: topStart.visible
        ? topStart.x + topStart.width + segmentSpacing : leftInset
    readonly property real topCenterMaxX: topEnd.visible
        ? topEnd.x - topCenter.width - segmentSpacing
        : width - rightInset - topCenter.width
    readonly property bool topCenterFits: !topCenter.visible
        || topCenterMinX <= topCenterMaxX
    readonly property bool topEdgeSegmentsFit: !topStart.visible || !topEnd.visible
        || topStart.x + topStart.width + segmentSpacing <= topEnd.x
    readonly property bool topCollision: !topEdgeSegmentsFit || !topCenterFits

    readonly property real bottomCenterDesiredX: (width - bottomCenter.width) / 2
    readonly property real bottomCenterMinX: bottomStart.visible
        ? bottomStart.x + bottomStart.width + segmentSpacing : leftInset
    readonly property real bottomCenterMaxX: bottomEnd.visible
        ? bottomEnd.x - bottomCenter.width - segmentSpacing
        : width - rightInset - bottomCenter.width
    readonly property bool bottomCenterFits: !bottomCenter.visible
        || bottomCenterMinX <= bottomCenterMaxX
    readonly property bool bottomEdgeSegmentsFit: !bottomStart.visible || !bottomEnd.visible
        || bottomStart.x + bottomStart.width + segmentSpacing <= bottomEnd.x
    readonly property bool bottomCollision: !bottomEdgeSegmentsFit || !bottomCenterFits

    function _clamp(value, minimum, maximum) {
        return Math.max(minimum, Math.min(maximum, value))
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
