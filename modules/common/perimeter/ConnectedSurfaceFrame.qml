import QtQuick

Item {
    id: root

    required property var geometry
    property color fillColor: "white"
    property color borderColor: "transparent"
    property real borderWidth: geometry.borderWidth ?? 0
    property real connectorBorderWidth: 0

    readonly property Item bodyItem: body
    readonly property Item connectorItem: connector
    readonly property rect visualBounds: geometry.visualBounds
    readonly property rect blurRect: geometry.blurRect

    visible: geometry.valid && geometry.progress > 0

    Rectangle {
        id: body
        x: root.geometry.bodyRect.x + root.geometry.offsetX
        y: root.geometry.bodyRect.y + root.geometry.offsetY
        width: root.geometry.bodyRect.width
        height: root.geometry.bodyRect.height
        radius: Math.min(root.geometry.outerRadius, width / 2, height / 2)
        color: root.fillColor
        border.color: root.borderColor
        border.width: root.borderWidth
        visible: root.visible && width > 0 && height > 0
        opacity: root.geometry.progress
    }

    // Render after the body so seamOverlap covers the body's border at the
    // attachment edge. Connector border is disabled by default to avoid a
    // double-line seam; a future unified outline renderer can replace it
    // without changing the geometry/input contracts.
    ConnectedSurfaceConnector {
        id: connector
        geometry: root.geometry
        fillColor: root.fillColor
        strokeColor: root.borderColor
        strokeWidth: root.connectorBorderWidth
    }
}
