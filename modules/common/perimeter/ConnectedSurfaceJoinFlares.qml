import QtQuick

// Concave union shoulders for direct Bar/Screen Edge attachments.
//
// Caelestia gets this silhouette from its blob-union renderer. Hadalis keeps
// its existing connected-surface architecture and approximates the same
// tangent transition with small quarter-circle inverse corners. No stem is
// drawn: each flare only fills the outside corner between the already-touching
// source edge and popup body.
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
    readonly property real radius: Math.max(0, Math.min(
        root.flareRadius,
        root.bodyItem?.width / 2 ?? 0,
        root.bodyItem?.height / 2 ?? 0)) * root.reveal

    visible: root.radius > 0
        && (root.joinTop || root.joinBottom || root.joinLeft || root.joinRight)

    component Flare: Canvas {
        required property string corner
        property color flareColor: root.fillColor
        property real r: root.radius

        width: r
        height: r
        visible: r > 0

        onRChanged: requestPaint()
        onFlareColorChanged: requestPaint()
        onCornerChanged: requestPaint()
        Component.onCompleted: requestPaint()

        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            const s = Math.min(width, height)
            if (!(s > 0))
                return

            // Cubic approximation of a quarter circle. The filled region is
            // the complement of that arc inside the r×r corner, producing the
            // characteristic concave "shoulder" where two surfaces unite.
            const k = 0.5522847498
            ctx.beginPath()

            if (corner === "topLeft") {
                ctx.moveTo(0, 0)
                ctx.lineTo(s, 0)
                ctx.lineTo(s, s)
                ctx.bezierCurveTo(s, s * (1 - k), s * k, 0, 0, 0)
            } else if (corner === "topRight") {
                ctx.moveTo(s, 0)
                ctx.lineTo(0, 0)
                ctx.lineTo(0, s)
                ctx.bezierCurveTo(0, s * (1 - k), s * (1 - k), 0, s, 0)
            } else if (corner === "bottomLeft") {
                ctx.moveTo(0, s)
                ctx.lineTo(s, s)
                ctx.lineTo(s, 0)
                ctx.bezierCurveTo(s, s * k, s * k, s, 0, s)
            } else if (corner === "bottomRight") {
                ctx.moveTo(s, s)
                ctx.lineTo(0, s)
                ctx.lineTo(0, 0)
                ctx.bezierCurveTo(0, s * k, s * (1 - k), s, s, s)
            } else if (corner === "leftTop") {
                ctx.moveTo(0, 0)
                ctx.lineTo(0, s)
                ctx.lineTo(s, s)
                ctx.bezierCurveTo(s * (1 - k), s, 0, s * k, 0, 0)
            } else if (corner === "leftBottom") {
                ctx.moveTo(0, s)
                ctx.lineTo(0, 0)
                ctx.lineTo(s, 0)
                ctx.bezierCurveTo(s * (1 - k), 0, 0, s * (1 - k), 0, s)
            } else if (corner === "rightTop") {
                ctx.moveTo(s, 0)
                ctx.lineTo(s, s)
                ctx.lineTo(0, s)
                ctx.bezierCurveTo(s * k, s, s, s * k, s, 0)
            } else if (corner === "rightBottom") {
                ctx.moveTo(s, s)
                ctx.lineTo(s, 0)
                ctx.lineTo(0, 0)
                ctx.bezierCurveTo(s * k, 0, s, s * (1 - k), s, s)
            } else {
                return
            }

            ctx.closePath()
            ctx.fillStyle = flareColor
            ctx.fill()
        }
    }

    // Horizontal attachments: flare tangent-wise beyond the body endpoints.
    Flare {
        corner: "topLeft"
        visible: root.joinTop && !root.joinLeft && r > 0
        x: root.bodyOrigin.x - r
        y: root.bodyOrigin.y
    }
    Flare {
        corner: "topRight"
        visible: root.joinTop && !root.joinRight && r > 0
        x: root.bodyOrigin.x + root.bodyItem.width
        y: root.bodyOrigin.y
    }
    Flare {
        corner: "bottomLeft"
        visible: root.joinBottom && !root.joinLeft && r > 0
        x: root.bodyOrigin.x - r
        y: root.bodyOrigin.y + root.bodyItem.height - r
    }
    Flare {
        corner: "bottomRight"
        visible: root.joinBottom && !root.joinRight && r > 0
        x: root.bodyOrigin.x + root.bodyItem.width
        y: root.bodyOrigin.y + root.bodyItem.height - r
    }

    // Vertical attachments: flare above/below the body endpoints.
    Flare {
        corner: "leftTop"
        visible: root.joinLeft && !root.joinTop && r > 0
        x: root.bodyOrigin.x
        y: root.bodyOrigin.y - r
    }
    Flare {
        corner: "leftBottom"
        visible: root.joinLeft && !root.joinBottom && r > 0
        x: root.bodyOrigin.x
        y: root.bodyOrigin.y + root.bodyItem.height
    }
    Flare {
        corner: "rightTop"
        visible: root.joinRight && !root.joinTop && r > 0
        x: root.bodyOrigin.x + root.bodyItem.width - r
        y: root.bodyOrigin.y - r
    }
    Flare {
        corner: "rightBottom"
        visible: root.joinRight && !root.joinBottom && r > 0
        x: root.bodyOrigin.x + root.bodyItem.width - r
        y: root.bodyOrigin.y + root.bodyItem.height
    }
}
