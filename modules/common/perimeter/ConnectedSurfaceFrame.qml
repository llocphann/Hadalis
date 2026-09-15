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
    readonly property Item blurItem: blurBounds
    readonly property rect visualBounds: geometry.visualBounds
    readonly property rect blurRect: geometry.blurRect

    visible: geometry.valid && geometry.progress > 0

    // Expanded rectangular blur proxy. It never participates in the input mask.
    Item {
        id: blurBounds
        x: root.geometry.blurRect.x
        y: root.geometry.blurRect.y
        width: root.geometry.blurRect.width
        height: root.geometry.blurRect.height
    }

    Rectangle {
        id: body
        x: root.geometry.animatedBodyRect.x
        y: root.geometry.animatedBodyRect.y
        width: root.geometry.animatedBodyRect.width
        height: root.geometry.animatedBodyRect.height
        radius: Math.min(root.geometry.outerRadius, width / 2, height / 2)
        color: root.fillColor
        border.color: root.borderColor
        border.width: root.borderWidth
        visible: root.visible && width > 0 && height > 0
        opacity: root.geometry.progress
    }

    // Render after the body so seamOverlap covers the body's border at the
    // attachment edge. Connector border is disabled by default to avoid a
    // double-line seam until a unified outline renderer replaces it.
    ConnectedSurfaceConnector {
        id: connector
        geometry: root.geometry
        fillColor: root.fillColor
        strokeColor: root.borderColor
        strokeWidth: root.connectorBorderWidth
    }
}
