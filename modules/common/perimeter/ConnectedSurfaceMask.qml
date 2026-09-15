import QtQuick
import Quickshell

Region {
    id: root

    required property Item bodyItem
    required property Item connectorItem
    property real bodyRadius: 0
    property real connectorRadius: 0

    // Keep input authority tied to the actual rendered items. Do not replace
    // this union with geometry.visualBounds: that rectangle would accept input
    // in the empty corners/space around a connected surface.
    Region {
        item: root.bodyItem
        radius: root.bodyRadius
    }

    Region {
        item: root.connectorItem
        radius: root.connectorRadius
    }
}
