import QtQuick
import Quickshell

Region {
    id: root

    required property var geometry
    required property Item bodyItem
    required property Item connectorItem

    readonly property bool active: geometry?.valid === true
        && Number(geometry?.progress ?? 0) > 0
    readonly property real bodyRadius: Math.min(geometry.outerRadius,
        bodyItem.width / 2, bodyItem.height / 2)
    readonly property real connectorRadius: Math.min(geometry.neckRadius,
        connectorItem.width / 2, connectorItem.height / 2)

    // Region { item: null } can be interpreted as the whole surface during
    // compositor map/unmap transitions. Keep a zero-area item in the same
    // visual tree so invalid/hidden connected surfaces remain click-through.
    property Item _emptyItem: Item {
        parent: root.bodyItem?.parent ?? null
        width: 0
        height: 0
        visible: false
    }

    // Keep input authority tied to the actual rendered items. Do not replace
    // this union with geometry.visualBounds or geometry.blurRect: those
    // rectangles would accept input in empty space around the connected shape.
    // Quickshell Region follows item geometry, not item visibility, so swap in
    // the explicit zero-area sentinel while the connected geometry is inactive.
    Region {
        item: root.active ? root.bodyItem : root._emptyItem
        radius: root.bodyRadius
    }

    Region {
        item: root.active ? root.connectorItem : root._emptyItem
        radius: root.connectorRadius
    }
}
