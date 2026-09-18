pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common.widgets

// Curved inward shadow for the shell's inverse quarter-circle perimeter corners.
//
// The solid RoundCorner occupies the area outside the quarter circle. This
// primitive paints only the matching quarter-disc on the wallpaper side, with
// a radial falloff from transparent to the configured perimeter shadow ink.
// Clipping the paint to the quarter-disc is important: a plain RadialGradient
// fills the square outside its radius too, which makes physical screen corners
// look like perpendicular/square shadow strips instead of one rounded perimeter.
Canvas {
    id: root

    required property int corner
    property real cornerRadius: 0
    property real shadowExtent: 0
    property color shadowColor: "transparent"

    readonly property bool isTop:
        corner === RoundCorner.CornerEnum.TopLeft
        || corner === RoundCorner.CornerEnum.TopRight
    readonly property bool isLeft:
        corner === RoundCorner.CornerEnum.TopLeft
        || corner === RoundCorner.CornerEnum.BottomLeft

    width: Math.max(0, root.cornerRadius)
    height: Math.max(0, root.cornerRadius)
    visible: root.cornerRadius > 0
        && root.shadowExtent > 0
        && root.shadowColor.a > 0
    antialiasing: true

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onCornerChanged: requestPaint()
    onCornerRadiusChanged: requestPaint()
    onShadowExtentChanged: requestPaint()
    onShadowColorChanged: requestPaint()
    Component.onCompleted: requestPaint()

    onPaint: {
        const ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)

        const r = Math.min(width, height)
        const extent = Math.max(0, Math.min(root.shadowExtent, r))
        if (!(r > 0) || !(extent > 0) || root.shadowColor.a <= 0)
            return

        let cx = 0
        let cy = 0
        let start = 0
        let end = Math.PI / 2

        if (root.corner === RoundCorner.CornerEnum.TopLeft) {
            cx = r
            cy = r
            start = Math.PI
            end = Math.PI * 1.5
        } else if (root.corner === RoundCorner.CornerEnum.TopRight) {
            cx = 0
            cy = r
            start = Math.PI * 1.5
            end = Math.PI * 2
        } else if (root.corner === RoundCorner.CornerEnum.BottomLeft) {
            cx = r
            cy = 0
            start = Math.PI / 2
            end = Math.PI
        }

        const inner = Math.max(0, r - extent)
        const gradient = ctx.createRadialGradient(cx, cy, inner, cx, cy, r)
        gradient.addColorStop(0, Qt.rgba(
            root.shadowColor.r, root.shadowColor.g, root.shadowColor.b, 0))
        gradient.addColorStop(1, root.shadowColor)

        // Paint only the quarter-disc. Pixels outside the radius remain fully
        // transparent instead of inheriting the last radial gradient stop.
        ctx.beginPath()
        ctx.moveTo(cx, cy)
        ctx.arc(cx, cy, r, start, end, false)
        ctx.closePath()
        ctx.fillStyle = gradient
        ctx.fill()
    }
}
