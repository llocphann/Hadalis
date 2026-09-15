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

    // Keep input authority tied to the actual rendered items. Do not replace
    // this union with geometry.visualBounds or geometry.blurRect: those
    // rectangles would accept input in empty space around the connected shape.
    // Quickshell Region follows item geometry, not item visibility, so detach
    // inactive items explicitly to keep hidden/invalid surfaces click-through.
    Region {
        item: root.active ? root.bodyItem : null
        radius: root.bodyRadius
    }

    Region {
        item: root.active ? root.connectorItem : null
        radius: root.connectorRadius
    }
}
