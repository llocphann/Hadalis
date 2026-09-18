import QtQuick
import QtQuick.Shapes

Item {
    id: root

    enum CornerEnum { TopLeft, TopRight, BottomLeft, BottomRight }
    property var corner: RoundCorner.CornerEnum.TopLeft
    property alias leftVisualMargin: shape.anchors.leftMargin
    property alias topVisualMargin: shape.anchors.topMargin
    property alias rightVisualMargin: shape.anchors.rightMargin
    property alias bottomVisualMargin: shape.anchors.bottomMargin

    property real implicitSize: 25
    property color color: "#000000"

    // Optional inward shadow which follows the inverse quarter-circle itself.
    // This is used by Screen Edge/Bar chrome so depth does not stop where a
    // straight gradient reaches a rounded corner.
    property bool shadowEnabled: false
    property color shadowColor: "transparent"
    property real shadowExtent: 0

    implicitWidth: implicitSize
    implicitHeight: implicitSize

    property bool isTopLeft: corner === RoundCorner.CornerEnum.TopLeft
    property bool isBottomLeft: corner === RoundCorner.CornerEnum.BottomLeft
    property bool isTopRight: corner === RoundCorner.CornerEnum.TopRight
    property bool isBottomRight: corner === RoundCorner.CornerEnum.BottomRight
    property bool isTop: isTopLeft || isTopRight
    property bool isBottom: isBottomLeft || isBottomRight
    property bool isLeft: isTopLeft || isBottomLeft
    property bool isRight: isTopRight || isBottomRight

    readonly property real _r: Math.max(0, root.implicitSize)
    readonly property real _k: 0.5522847498307936

    readonly property point _wedgeStart: root.isTopLeft ? Qt.point(0, 0)
        : root.isTopRight ? Qt.point(root._r, 0)
        : root.isBottomLeft ? Qt.point(0, root._r)
        : Qt.point(root._r, root._r)

    readonly property point _arcStart: root.isTopLeft ? Qt.point(0, root._r)
        : root.isTopRight ? Qt.point(root._r, root._r)
        : root.isBottomLeft ? Qt.point(0, 0)
        : Qt.point(root._r, 0)

    readonly property point _arcEnd: root.isTopLeft ? Qt.point(root._r, 0)
        : root.isTopRight ? Qt.point(0, 0)
        : root.isBottomLeft ? Qt.point(root._r, root._r)
        : Qt.point(0, root._r)

    readonly property point _control1: root.isTopLeft
        ? Qt.point(0, root._r * (1 - root._k))
        : root.isTopRight
            ? Qt.point(root._r, root._r * (1 - root._k))
        : root.isBottomLeft
            ? Qt.point(0, root._r * root._k)
        : Qt.point(root._r, root._r * root._k)

    readonly property point _control2: root.isTopLeft
        ? Qt.point(root._r * (1 - root._k), 0)
        : root.isTopRight
            ? Qt.point(root._r * root._k, 0)
        : root.isBottomLeft
            ? Qt.point(root._r * (1 - root._k), root._r)
        : Qt.point(root._r * root._k, root._r)

    Shape {
        id: shape
        width: root._r
        height: root._r
        anchors {
            top: root.isTop ? parent.top : undefined
            bottom: root.isBottom ? parent.bottom : undefined
            left: root.isLeft ? parent.left : undefined
            right: root.isRight ? parent.right : undefined
        }
        layer.enabled: true
        layer.smooth: true
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            id: fillPath
            strokeWidth: 0
            fillColor: root.color
            pathHints: ShapePath.PathSolid & ShapePath.PathNonIntersecting
            startX: root._wedgeStart.x
            startY: root._wedgeStart.y

            PathLine {
                x: root._arcStart.x
                y: root._arcStart.y
            }
            PathCubic {
                control1X: root._control1.x
                control1Y: root._control1.y
                control2X: root._control2.x
                control2Y: root._control2.y
                x: root._arcEnd.x
                y: root._arcEnd.y
            }
            PathLine {
                x: root._wedgeStart.x
                y: root._wedgeStart.y
            }
        }
    }

    // Draw the falloff *inside* the transparent/workspace side of the inverse
    // corner. Repeated one-pixel arcs are intentionally simple and deterministic
    // on Qt/Wayland, unlike layer-effect padding which can be clipped by a
    // layer-shell surface.
    Canvas {
        id: shadowCanvas
        z: -1
        anchors.fill: shape
        visible: root.shadowEnabled
            && root.shadowExtent > 0
            && root._r > 0
            && root.shadowColor.a > 0
        antialiasing: true

        onVisibleChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections {
            target: root
            function onCornerChanged() { shadowCanvas.requestPaint() }
            function onShadowColorChanged() { shadowCanvas.requestPaint() }
            function onShadowExtentChanged() { shadowCanvas.requestPaint() }
            function onShadowEnabledChanged() { shadowCanvas.requestPaint() }
            function onImplicitSizeChanged() { shadowCanvas.requestPaint() }
        }

        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            if (!visible)
                return

            const r = root._r
            const extent = Math.max(1, Math.min(root.shadowExtent, r))
            let cx = 0
            let cy = 0
            let a0 = 0
            let a1 = 0

            if (root.isTopLeft) {
                cx = r; cy = r; a0 = Math.PI; a1 = Math.PI * 1.5
            } else if (root.isTopRight) {
                cx = 0; cy = r; a0 = Math.PI * 1.5; a1 = Math.PI * 2
            } else if (root.isBottomLeft) {
                cx = r; cy = 0; a0 = Math.PI * 0.5; a1 = Math.PI
            } else {
                cx = 0; cy = 0; a0 = 0; a1 = Math.PI * 0.5
            }

            ctx.strokeStyle = root.shadowColor
            ctx.lineWidth = 1.4
            const steps = Math.max(1, Math.ceil(extent))
            for (let i = 0; i < steps; i++) {
                const t = i / steps
                const rr = Math.max(0.5, r - i - 0.5)
                // Strongest next to the chrome, then a smooth quadratic fade.
                ctx.globalAlpha = (1 - t) * (1 - t)
                ctx.beginPath()
                ctx.arc(cx, cy, rr, a0, a1, false)
                ctx.stroke()
            }
            ctx.globalAlpha = 1
        }
    }
}
