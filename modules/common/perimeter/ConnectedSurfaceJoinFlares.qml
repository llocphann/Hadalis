import QtQuick
import Quickshell

// CONNECTED-SURFACE-OUTWARD-FLARE-LOCK (maintainer clarified 2026-09-19):
// Contact corners MUST flare outward from the popup/sidebar/dashboard body into
// Screen Edge/Bar. They must never be implemented by rounding the attached body
// corner inward. The joined body edge stays square; these inverse elliptical
// shoulders occupy only the OUTSIDE endpoint space.
//
// Caelestia's BlobGroup smooth-union reads broad/flat at the border. Hadalis
// keeps that spatial language with a radius-wide tangent and compressed
// cross-axis depth. PerimeterTokens.joinFlareRadius follows the same user
// Border Radius as Screen Edge/Bar, while joinFlareCrossScale controls only the
// flattening depth. Do not modify ScreenEdges.qml or Bar corner ownership here.
Item {
    id: root

    required property Item bodyItem
    property color fillColor: "white"
    property real flareRadius: PerimeterTokens.joinFlareRadius
    property real crossScale: PerimeterTokens.joinFlareCrossScale
    property real progress: 1
    property bool joinTop: false
    property bool joinBottom: false
    property bool joinLeft: false
    property bool joinRight: false

    readonly property real reveal: Math.max(0, Math.min(1, root.progress))

    // mapToItem() does not by itself invalidate when an ancestor/item transform
    // moves. Watch the relative transform so sliding connected bodies keep their
    // endpoint shoulders mapped to the live body position.
    property int bodyGeometryRevision: 0
    readonly property point bodyOrigin: {
        const dependency = root.bodyGeometryRevision
        if (dependency < 0 || !root.bodyItem)
            return Qt.point(0, 0)
        return root.bodyItem.mapToItem(root, 0, 0)
    }

    TransformWatcher {
        a: root
        b: root.bodyItem
        onTransformChanged: root.bodyGeometryRevision++
    }

    readonly property real radius: Math.max(0, Math.min(
        root.flareRadius,
        root.bodyItem?.width / 2 ?? 0,
        root.bodyItem?.height / 2 ?? 0))
    readonly property real depth: Math.max(0,
        Math.min(root.radius, root.radius * Math.max(0.20, Math.min(1, root.crossScale))))

    visible: root.reveal > 0.001 && root.radius > 0 && root.depth > 0
        && (root.joinTop || root.joinBottom || root.joinLeft || root.joinRight)

    component Flare: Canvas {
        id: flare

        required property string flareCorner
        property color flareColor: root.fillColor

        visible: width > 0 && height > 0
        antialiasing: true

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onFlareColorChanged: requestPaint()
        onFlareCornerChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            if (!(width > 0 && height > 0))
                return

            const k = 0.5522847498307936
            const w = width
            const h = height
            const corner = flare.flareCorner

            ctx.beginPath()

            if (corner === "topLeft" || corner === "rightBottom") {
                // Inverse top-right ellipse.
                ctx.moveTo(w, 0)
                ctx.lineTo(w, h)
                ctx.bezierCurveTo(w, h * (1 - k), w * k, 0, 0, 0)
                ctx.lineTo(w, 0)
            } else if (corner === "topRight" || corner === "leftBottom") {
                // Inverse top-left ellipse.
                ctx.moveTo(0, 0)
                ctx.lineTo(0, h)
                ctx.bezierCurveTo(0, h * (1 - k), w * (1 - k), 0, w, 0)
                ctx.lineTo(0, 0)
            } else if (corner === "bottomLeft" || corner === "rightTop") {
                // Inverse bottom-right ellipse.
                ctx.moveTo(w, h)
                ctx.lineTo(w, 0)
                ctx.bezierCurveTo(w, h * k, w * k, h, 0, h)
                ctx.lineTo(w, h)
            } else if (corner === "bottomRight" || corner === "leftTop") {
                // Inverse bottom-left ellipse.
                ctx.moveTo(0, h)
                ctx.lineTo(0, 0)
                ctx.bezierCurveTo(0, h * k, w * (1 - k), h, w, h)
                ctx.lineTo(0, h)
            } else {
                return
            }

            ctx.closePath()
            ctx.fillStyle = flare.flareColor
            ctx.fill()
        }
    }

    // Top/bottom attachment: tangent smoothing stays 20px wide while border
    // depth is compressed. This is the characteristic flat Caelestia contact.
    Flare {
        flareCorner: "topLeft"
        visible: root.joinTop && !root.joinLeft && root.radius > 0
        x: root.bodyOrigin.x - root.radius
        y: root.bodyOrigin.y
        width: root.radius
        height: root.depth
    }
    Flare {
        flareCorner: "topRight"
        visible: root.joinTop && !root.joinRight && root.radius > 0
        x: root.bodyOrigin.x + root.bodyItem.width
        y: root.bodyOrigin.y
        width: root.radius
        height: root.depth
    }
    Flare {
        flareCorner: "bottomLeft"
        visible: root.joinBottom && !root.joinLeft && root.radius > 0
        x: root.bodyOrigin.x - root.radius
        y: root.bodyOrigin.y + root.bodyItem.height - root.depth
        width: root.radius
        height: root.depth
    }
    Flare {
        flareCorner: "bottomRight"
        visible: root.joinBottom && !root.joinRight && root.radius > 0
        x: root.bodyOrigin.x + root.bodyItem.width
        y: root.bodyOrigin.y + root.bodyItem.height - root.depth
        width: root.radius
        height: root.depth
    }

    // Left/right attachment uses the same geometry rotated 90 degrees.
    Flare {
        flareCorner: "leftTop"
        visible: root.joinLeft && !root.joinTop && root.radius > 0
        x: root.bodyOrigin.x
        y: root.bodyOrigin.y - root.radius
        width: root.depth
        height: root.radius
    }
    Flare {
        flareCorner: "leftBottom"
        visible: root.joinLeft && !root.joinBottom && root.radius > 0
        x: root.bodyOrigin.x
        y: root.bodyOrigin.y + root.bodyItem.height
        width: root.depth
        height: root.radius
    }
    Flare {
        flareCorner: "rightTop"
        visible: root.joinRight && !root.joinTop && root.radius > 0
        x: root.bodyOrigin.x + root.bodyItem.width - root.depth
        y: root.bodyOrigin.y - root.radius
        width: root.depth
        height: root.radius
    }
    Flare {
        flareCorner: "rightBottom"
        visible: root.joinRight && !root.joinBottom && root.radius > 0
        x: root.bodyOrigin.x + root.bodyItem.width - root.depth
        y: root.bodyOrigin.y + root.bodyItem.height
        width: root.depth
        height: root.radius
    }
}
