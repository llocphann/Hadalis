import qs.modules.common.widgets
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

    readonly property bool horizontalAttachment:
        geometry.edge === "top" || geometry.edge === "bottom"
    readonly property real contactRadius: Math.max(0, Math.min(
        geometry.outerRadius,
        horizontalAttachment
            ? geometry.animatedBodyRect.width / 2
            : geometry.animatedBodyRect.height / 2,
        horizontalAttachment
            ? geometry.animatedBodyRect.height
            : geometry.animatedBodyRect.width))

    visible: geometry.valid && geometry.progress > 0

    // Expanded rectangular blur proxy. It never participates in the input mask.
    Item {
        id: blurBounds
        x: root.geometry.blurRect.x
        y: root.geometry.blurRect.y
        width: root.geometry.blurRect.width
        height: root.geometry.blurRect.height
    }

    // Keep the normal rounded body for the two free corners. The attached edge
    // is squared by attachedEdgeFill below, then two inverse quarter-circles
    // extend into the bar/screen edge. Together with the bar underneath this
    // produces Caelestia's smooth-union silhouette instead of a thin stem.
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
    }

    Rectangle {
        id: attachedEdgeFill
        z: 1
        visible: body.visible && root.contactRadius > 0
        color: root.fillColor

        x: root.geometry.edge === "right"
            ? body.x + body.width - width
            : body.x
        y: root.geometry.edge === "bottom"
            ? body.y + body.height - height
            : body.y
        width: root.horizontalAttachment
            ? body.width
            : Math.min(root.contactRadius, body.width)
        height: root.horizontalAttachment
            ? Math.min(root.contactRadius, body.height)
            : body.height
    }

    // First concave contact fillet (top for vertical bars, left for horizontal).
    RoundCorner {
        id: contactStart
        z: 2
        visible: body.visible && root.contactRadius > 0
        width: root.contactRadius
        height: root.contactRadius
        implicitSize: Math.round(root.contactRadius)
        color: root.fillColor
        arcColor: root.borderColor
        arcWidth: root.borderWidth

        x: {
            if (root.geometry.edge === "left")
                return body.x
            if (root.geometry.edge === "right")
                return body.x + body.width - width
            return body.x - width
        }
        y: {
            if (root.geometry.edge === "left" || root.geometry.edge === "right")
                return body.y - height
            if (root.geometry.edge === "top")
                return body.y
            return body.y + body.height - height
        }
        corner: {
            if (root.geometry.edge === "left")
                return RoundCorner.CornerEnum.BottomLeft
            if (root.geometry.edge === "right")
                return RoundCorner.CornerEnum.BottomRight
            if (root.geometry.edge === "top")
                return RoundCorner.CornerEnum.TopRight
            return RoundCorner.CornerEnum.BottomRight
        }
    }

    // Second concave contact fillet (bottom for vertical bars, right for horizontal).
    RoundCorner {
        id: contactEnd
        z: 2
        visible: body.visible && root.contactRadius > 0
        width: root.contactRadius
        height: root.contactRadius
        implicitSize: Math.round(root.contactRadius)
        color: root.fillColor
        arcColor: root.borderColor
        arcWidth: root.borderWidth

        x: {
            if (root.geometry.edge === "left")
                return body.x
            if (root.geometry.edge === "right")
                return body.x + body.width - width
            return body.x + body.width
        }
        y: {
            if (root.geometry.edge === "left" || root.geometry.edge === "right")
                return body.y + body.height
            if (root.geometry.edge === "top")
                return body.y
            return body.y + body.height - height
        }
        corner: {
            if (root.geometry.edge === "left")
                return RoundCorner.CornerEnum.TopLeft
            if (root.geometry.edge === "right")
                return RoundCorner.CornerEnum.TopRight
            if (root.geometry.edge === "top")
                return RoundCorner.CornerEnum.TopLeft
            return RoundCorner.CornerEnum.BottomLeft
        }
    }

    // Keep the connector object as a geometry/input compatibility shim. The
    // visible presentation no longer uses the old narrow Bézier stem.
    ConnectedSurfaceConnector {
        id: connector
        geometry: root.geometry
        fillColor: root.fillColor
        strokeColor: root.borderColor
        strokeWidth: root.connectorBorderWidth
        opacity: 0
    }
}
