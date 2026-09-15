import QtQuick
import Quickshell

Region {
    id: root

    required property var geometry
    required property Item bodyItem
    required property Item connectorItem

    readonly property real bodyRadius: Math.min(geometry.outerRadius,
        bodyItem.width / 2, bodyItem.height / 2)
    readonly property real connectorRadius: Math.min(geometry.neckRadius,
        connectorItem.width / 2, connectorItem.height / 2)

    // Keep input authority tied to the actual rendered items. Do not replace
    // this union with geometry.visualBounds or geometry.blurRect: those
    // rectangles would accept input in empty space around the connected shape.
    Region {
        item: root.bodyItem
        radius: root.bodyRadius
    }

    Region {
        item: root.connectorItem
        radius: root.connectorRadius
    }
}
