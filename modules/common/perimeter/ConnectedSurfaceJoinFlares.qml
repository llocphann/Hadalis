import QtQuick

// Circular smooth-union shoulders for direct Bar/Screen Edge attachments.
//
// Caelestia's blob shader switched from a polynomial/squircle blend to a
// circular smooth-min in a0acd1a. At a perpendicular join that boundary is a
// true quarter circle. Draw the fillet directly on Canvas instead of routing it
// through the generic RoundCorner Shape renderer; that keeps all eight
// orientations pixel-identical and avoids the lower-corner winding artifacts.
Item {
    id: root

    required property Item bodyItem
    property color fillColor: "white"
    property real flareRadius: PerimeterTokens.joinFlareRadius
    property real progress: 1
    property bool joinTop: false
    property bool joinBottom: false
    property bool joinLeft: false
    property bool joinRight: false

    readonly property real reveal: Math.max(0, Math.min(1, root.progress))
    readonly property point bodyOrigin: root.bodyItem
        ? root.bodyItem.mapToItem(root, 0, 0) : Qt.point(0, 0)

    // Caelestia keeps smoothing independent from the panel corner radius.
    // Keep the fillet fully formed while the body slides under its owner.
    readonly property real radius: Math.max(0, Math.min(
        root.flareRadius,
        root.bodyItem?.width / 2 ?? 0,
        root.bodyItem?.height / 2 ?? 0))

    visible: root.reveal > 0.001 && root.radius > 0
        && (root.joinTop || root.joinBottom || root.joinLeft || root.joinRight)

    component Flare: Canvas {
        id: flare

        required property string flareCorner
        property color flareColor: root.fillColor
        property real r: root.radius

        width: r
        height: r
        visible: r > 0
        antialiasing: true

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onRChanged: requestPaint()
        onFlareColorChanged: requestPaint()
        onFlareCornerChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            if (!(width > 0 && height > 0))
                return

            // Cubic approximation of a circular quarter arc. This is only the
            // rasterisation primitive; the radius itself is Caelestia's
            // smoothing radius, not the popup/card outer radius.
            const k = 0.5522847498
            const r = Math.min(width, height)
            const corner = flare.flareCorner

            ctx.beginPath()

            if (corner === "topLeft" || corner === "rightBottom") {
                // Inverse TopRight.
                ctx.moveTo(r, 0)
                ctx.lineTo(r, r)
                ctx.bezierCurveTo(r, r * (1 - k), r * k, 0, 0, 0)
                ctx.lineTo(r, 0)
            } else if (corner === "topRight" || corner === "leftBottom") {
                // Inverse TopLeft.
                ctx.moveTo(0, 0)
                ctx.lineTo(0, r)
                ctx.bezierCurveTo(0, r * (1 - k), r * (1 - k), 0, r, 0)
                ctx.lineTo(0, 0)
            } else if (corner === "bottomLeft" || corner === "rightTop") {
                // Inverse BottomRight.
                ctx.moveTo(r, r)
                ctx.lineTo(r, 0)
                ctx.bezierCurveTo(r, r * k, r * k, r, 0, r)
                ctx.lineTo(r, r)
            } else if (corner === "bottomRight" || corner === "leftTop") {
                // Inverse BottomLeft.
                ctx.moveTo(0, r)
                ctx.lineTo(0, 0)
                ctx.bezierCurveTo(0, r * k, r * (1 - k), r, r, r)
                ctx.lineTo(0, r)
            } else {
                return
            }

            ctx.closePath()
            ctx.fillStyle = flare.flareColor
            ctx.fill()
        }
    }

    // Horizontal attachments: flare tangent-wise beyond the body endpoints.
    Flare {
        flareCorner: "topLeft"
        visible: root.joinTop && !root.joinLeft && r > 0
        x: root.bodyOrigin.x - r
        y: root.bodyOrigin.y
    }
    Flare {
        flareCorner: "topRight"
        visible: root.joinTop && !root.joinRight && r > 0
        x: root.bodyOrigin.x + root.bodyItem.width
        y: root.bodyOrigin.y
    }
    Flare {
        flareCorner: "bottomLeft"
        visible: root.joinBottom && !root.joinLeft && r > 0
        x: root.bodyOrigin.x - r
        y: root.bodyOrigin.y + root.bodyItem.height - r
    }
    Flare {
        flareCorner: "bottomRight"
        visible: root.joinBottom && !root.joinRight && r > 0
        x: root.bodyOrigin.x + root.bodyItem.width
        y: root.bodyOrigin.y + root.bodyItem.height - r
    }

    // Vertical attachments: flare above/below the body endpoints.
    Flare {
        flareCorner: "leftTop"
        visible: root.joinLeft && !root.joinTop && r > 0
        x: root.bodyOrigin.x
        y: root.bodyOrigin.y - r
    }
    Flare {
        flareCorner: "leftBottom"
        visible: root.joinLeft && !root.joinBottom && r > 0
        x: root.bodyOrigin.x
        y: root.bodyOrigin.y + root.bodyItem.height
    }
    Flare {
        flareCorner: "rightTop"
        visible: root.joinRight && !root.joinTop && r > 0
        x: root.bodyOrigin.x + root.bodyItem.width - r
        y: root.bodyOrigin.y - r
    }
    Flare {
        flareCorner: "rightBottom"
        visible: root.joinRight && !root.joinBottom && r > 0
        x: root.bodyOrigin.x + root.bodyItem.width - r
        y: root.bodyOrigin.y + root.bodyItem.height
    }
}
