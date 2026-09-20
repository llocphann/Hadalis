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
    // Owner-authoritative contact planes in this item's coordinate space.
    // Negative means "use the mapped body edge" for compatibility. Consumers
    // connected to Bar/Screen Edge should pass the real owner seam explicitly.
    property real topContactPlane: -1
    property real bottomContactPlane: -1
    property real leftContactPlane: -1
    property real rightContactPlane: -1
    property bool joinTop: false
    property bool joinBottom: false
    property bool joinLeft: false
    property bool joinRight: false

    readonly property real reveal: Math.max(0, Math.min(1, root.progress))

    // mapToItem() is geometrically correct but does not itself create reactive
    // dependencies for every transform in the item/ancestor chain. Watch that
    // relative transform explicitly and map the complete body rect so endpoint
    // placement also follows animated scale, not only the transformed origin.
    property int bodyTransformRevision: 0
    readonly property rect bodyRect: {
        const dependency = root.bodyTransformRevision
        if (dependency < 0 || !root.bodyItem
                || root.bodyItem.width <= 0 || root.bodyItem.height <= 0)
            return Qt.rect(0, 0, 0, 0)
        return root.bodyItem.mapToItem(root, 0, 0,
            root.bodyItem.width, root.bodyItem.height)
    }
    readonly property real topContactY:
        root.topContactPlane >= 0 ? root.topContactPlane : root.bodyRect.y
    readonly property real bottomContactY:
        root.bottomContactPlane >= 0
            ? root.bottomContactPlane : root.bodyRect.y + root.bodyRect.height
    readonly property real leftContactX:
        root.leftContactPlane >= 0 ? root.leftContactPlane : root.bodyRect.x
    readonly property real rightContactX:
        root.rightContactPlane >= 0
            ? root.rightContactPlane : root.bodyRect.x + root.bodyRect.width

    TransformWatcher {
        a: root
        b: root.bodyItem
        onTransformChanged: root.bodyTransformRevision++
    }

    readonly property real radius: Math.max(0, Math.min(
        root.flareRadius,
        root.bodyRect.width / 2,
        root.bodyRect.height / 2))
    readonly property real depth: Math.max(0,
        Math.min(root.radius, root.radius * Math.max(0.20, Math.min(1, root.crossScale))))

    visible: root.reveal > 0.001 && root.radius > 0 && root.depth > 0
        && (root.joinTop || root.joinBottom || root.joinLeft || root.joinRight)

    // Ancestor visibility changes do not toggle each Canvas.visible property.
    // Bump a paint revision whenever the flare host becomes visible so reused
    // hover popups cannot return with a stale/empty Canvas texture.
    property int paintRevision: 0
    onVisibleChanged: {
        if (visible)
            root.paintRevision++
    }
    Component.onCompleted: root.paintRevision++

    component Flare: Canvas {
        id: flare

        required property string flareCorner
        property color flareColor: root.fillColor

        visible: width > 0 && height > 0
        antialiasing: true
        property int paintRevision: root.paintRevision

        function queuePaint(): void {
            if (available && visible && width > 0 && height > 0)
                requestPaint()
        }

        onAvailableChanged: queuePaint()
        onVisibleChanged: queuePaint()
        onWidthChanged: queuePaint()
        onHeightChanged: queuePaint()
        onFlareColorChanged: queuePaint()
        onFlareCornerChanged: queuePaint()
        onPaintRevisionChanged: queuePaint()
        Component.onCompleted: queuePaint()

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
        x: root.bodyRect.x - root.radius
        y: root.topContactY
        width: root.radius
        height: root.depth
    }
    Flare {
        flareCorner: "topRight"
        visible: root.joinTop && !root.joinRight && root.radius > 0
        x: root.bodyRect.x + root.bodyRect.width
        y: root.topContactY
        width: root.radius
        height: root.depth
    }
    Flare {
        flareCorner: "bottomLeft"
        visible: root.joinBottom && !root.joinLeft && root.radius > 0
        x: root.bodyRect.x - root.radius
        y: root.bottomContactY - root.depth
        width: root.radius
        height: root.depth
    }
    Flare {
        flareCorner: "bottomRight"
        visible: root.joinBottom && !root.joinRight && root.radius > 0
        x: root.bodyRect.x + root.bodyRect.width
        y: root.bottomContactY - root.depth
        width: root.radius
        height: root.depth
    }

    // Left/right attachment uses the same geometry rotated 90 degrees.
    Flare {
        flareCorner: "leftTop"
        visible: root.joinLeft && !root.joinTop && root.radius > 0
        x: root.leftContactX
        y: root.bodyRect.y - root.radius
        width: root.depth
        height: root.radius
    }
    Flare {
        flareCorner: "leftBottom"
        visible: root.joinLeft && !root.joinBottom && root.radius > 0
        x: root.leftContactX
        y: root.bodyRect.y + root.bodyRect.height
        width: root.depth
        height: root.radius
    }
    Flare {
        flareCorner: "rightTop"
        visible: root.joinRight && !root.joinTop && root.radius > 0
        x: root.rightContactX - root.depth
        y: root.bodyRect.y - root.radius
        width: root.depth
        height: root.radius
    }
    Flare {
        flareCorner: "rightBottom"
        visible: root.joinRight && !root.joinBottom && root.radius > 0
        x: root.rightContactX - root.depth
        y: root.bodyRect.y + root.bodyRect.height
        width: root.depth
        height: root.radius
    }
}
