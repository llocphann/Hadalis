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

    property int implicitSize: 25
    property color color: "#000000"

    // Optional hairline along only the curved edge. This keeps the component
    // usable as the classic solid inverse corner while allowing connected
    // surfaces to reproduce Caelestia's subtle outlined contact fillet.
    property color arcColor: "transparent"
    property real arcWidth: 0

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

    readonly property real arcCenterX: root.isLeft ? root.implicitSize : 0
    readonly property real arcCenterY: root.isTop ? root.implicitSize : 0
    readonly property real arcStartAngle: switch (root.corner) {
        case RoundCorner.CornerEnum.TopLeft: return 180
        case RoundCorner.CornerEnum.TopRight: return -90
        case RoundCorner.CornerEnum.BottomLeft: return 90
        case RoundCorner.CornerEnum.BottomRight: return 0
    }

    Shape {
        id: shape
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
            id: shapePath
            strokeWidth: 0
            fillColor: root.color
            pathHints: ShapePath.PathSolid & ShapePath.PathNonIntersecting

            startX: root.isLeft ? 0 : root.implicitSize
            startY: root.isTop ? 0 : root.implicitSize

            PathAngleArc {
                moveToStart: false
                centerX: root.arcCenterX
                centerY: root.arcCenterY
                radiusX: root.implicitSize
                radiusY: root.implicitSize
                startAngle: root.arcStartAngle
                sweepAngle: 90
            }
            PathLine {
                x: shapePath.startX
                y: shapePath.startY
            }
        }

        ShapePath {
            strokeWidth: root.arcWidth
            strokeColor: root.arcColor
            fillColor: "transparent"

            PathAngleArc {
                moveToStart: true
                centerX: root.arcCenterX
                centerY: root.arcCenterY
                radiusX: Math.max(0, root.implicitSize - root.arcWidth / 2)
                radiusY: Math.max(0, root.implicitSize - root.arcWidth / 2)
                startAngle: root.arcStartAngle
                sweepAngle: 90
            }
        }
    }
}
