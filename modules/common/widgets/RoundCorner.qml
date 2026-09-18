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

        // Render all four inverse corners from the same cubic quarter-circle
        // construction. This avoids the renderer-dependent bottom-corner
        // triangle/winding artifact from PathAngleArc and keeps the popup/bar
        // contact shoulders visually identical in every orientation.
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
}
