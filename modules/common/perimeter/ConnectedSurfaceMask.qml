import QtQuick
import Quickshell

Region {
    id: root

    required property var geometry
    required property Item bodyItem
    required property Item connectorItem
    property bool inputEnabled: true

    readonly property bool active: inputEnabled
        && geometry?.valid === true
        && Number(geometry?.progress ?? 0) > 0
    readonly property bool horizontalConnector: geometry?.edge === "top"
        || geometry?.edge === "bottom"
    readonly property bool sourceAtStart: geometry?.edge === "top"
        || geometry?.edge === "left"
    readonly property rect visibleBodyRect: geometry?.visibleBodyRect
        ?? Qt.rect(bodyItem.x, bodyItem.y, bodyItem.width, bodyItem.height)
    readonly property real bodyRadius: Math.min(geometry.outerRadius,
        root._visibleBodyItem.width / 2, root._visibleBodyItem.height / 2)
    readonly property real sourceExtent: Math.max(0, Math.min(
        horizontalConnector ? connectorItem.width : connectorItem.height,
        Number(geometry?.connectorSourceExtent ?? 0)))
    readonly property real bodyExtent: Math.max(sourceExtent,
        horizontalConnector ? connectorItem.width : connectorItem.height)
    readonly property real middleExtent: sourceExtent
        + (bodyExtent - sourceExtent) * 0.58

    // Region cannot consume Canvas alpha, so approximate the Bézier shoulder with
    // three overlapping rounded strips. This is deliberately tighter than using
    // the connector Canvas' full bounding rectangle, which would steal pointer
    // input from transparent corners outside the visible flare.
    function stripStart(total, fractionStart, fractionLength) {
        const length = total * fractionLength
        return root.sourceAtStart
            ? total * fractionStart
            : total - total * fractionStart - length
    }

    property Item _emptyItem: Item {
        parent: root.bodyItem?.parent ?? null
        width: 0
        height: 0
        visible: false
    }

    // Region cannot clip another Region, so expose only the body portion that is
    // actually visible outside the fixed Bar/Screen Edge reveal boundary.
    property Item _visibleBodyItem: Item {
        parent: root.bodyItem?.parent ?? null
        x: root.visibleBodyRect.x
        y: root.visibleBodyRect.y
        width: root.visibleBodyRect.width
        height: root.visibleBodyRect.height
        visible: false
    }

    property Item _sourceStrip: Item {
        parent: root.connectorItem
        visible: false
        x: root.horizontalConnector ? (parent.width - root.sourceExtent) / 2
            : root.stripStart(parent.width, 0, 0.42)
        y: root.horizontalConnector ? root.stripStart(parent.height, 0, 0.42)
            : (parent.height - root.sourceExtent) / 2
        width: root.horizontalConnector ? root.sourceExtent : parent.width * 0.42
        height: root.horizontalConnector ? parent.height * 0.42 : root.sourceExtent
    }

    property Item _middleStrip: Item {
        parent: root.connectorItem
        visible: false
        x: root.horizontalConnector ? (parent.width - root.middleExtent) / 2
            : root.stripStart(parent.width, 0.28, 0.5)
        y: root.horizontalConnector ? root.stripStart(parent.height, 0.28, 0.5)
            : (parent.height - root.middleExtent) / 2
        width: root.horizontalConnector ? root.middleExtent : parent.width * 0.5
        height: root.horizontalConnector ? parent.height * 0.5 : root.middleExtent
    }

    property Item _bodyStrip: Item {
        parent: root.connectorItem
        visible: false
        x: root.horizontalConnector ? 0
            : root.stripStart(parent.width, 0.66, 0.34)
        y: root.horizontalConnector ? root.stripStart(parent.height, 0.66, 0.34)
            : 0
        width: root.horizontalConnector ? parent.width : parent.width * 0.34
        height: root.horizontalConnector ? parent.height * 0.34 : parent.height
    }

    Region {
        item: root.active ? root._visibleBodyItem : root._emptyItem
        radius: root.bodyRadius
    }

    Region {
        item: root.active ? root._sourceStrip : root._emptyItem
        radius: Math.min(root.geometry.neckRadius,
            root._sourceStrip.width / 2, root._sourceStrip.height / 2)
    }

    Region {
        item: root.active ? root._middleStrip : root._emptyItem
        radius: Math.min(root.geometry.neckRadius,
            root._middleStrip.width / 2, root._middleStrip.height / 2)
    }

    Region {
        item: root.active ? root._bodyStrip : root._emptyItem
        radius: Math.min(root.geometry.neckRadius,
            root._bodyStrip.width / 2, root._bodyStrip.height / 2)
    }
}
