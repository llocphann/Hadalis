import qs.modules.common
import QtQuick
import QtQuick.Shapes
import QtQuick.Effects

// Error-only physical Screen Edge painter.
//
// This file is intentionally loaded by URL only after ScreenEdgeField reports a
// ShaderEffect.Error. Keep Shapes/Effects imports here so the healthy analytic
// path does not pull the legacy renderer/type graph into ScreenEdges.qml.
Item {
    id: root
    anchors.fill: parent

    readonly property var edgeRoot: parent.edgeRoot
    readonly property var frameHost: parent.frameHost

    Shape {
        id: frameShape
        anchors.fill: parent
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer

        readonly property real shadowRasterScale:
            root.edgeRoot.physicalShadowSize >= 12 ? 0.5 : 0.625
        layer.enabled: root.frameHost.physicalShadowActive
        layer.textureSize: root.frameHost.physicalShadowActive
            ? Qt.size(
                Math.max(1, Math.ceil(frameShape.width * frameShape.shadowRasterScale)),
                Math.max(1, Math.ceil(frameShape.height * frameShape.shadowRasterScale)))
            : Qt.size(0, 0)
        layer.smooth: true
        layer.effect: MultiEffect {
            shadowEnabled: root.frameHost.physicalShadowActive
            blurMax: Math.max(1, root.edgeRoot.physicalShadowSize)
            shadowBlur: 1.0
            autoPaddingEnabled: false
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
            shadowColor: Qt.alpha(
                Appearance.m3colors.m3shadow,
                root.edgeRoot.physicalShadowOpacity)
        }

        ShapePath {
            id: framePath

            fillColor: root.edgeRoot.edgeColor
            fillRule: ShapePath.OddEvenFill
            strokeColor: "transparent"
            strokeWidth: -1

            readonly property real innerLeft: root.frameHost.frameLeftInset
            readonly property real innerTop: root.frameHost.frameTopInset
            readonly property real innerRight:
                frameShape.width - root.frameHost.frameRightInset
            readonly property real innerBottom:
                frameShape.height - root.frameHost.frameBottomInset
            readonly property real r: Math.max(0, Math.min(
                root.edgeRoot.rounding,
                Math.max(0, innerRight - innerLeft) / 2,
                Math.max(0, innerBottom - innerTop) / 2))

            startX: -root.edgeRoot.outerPadding
            startY: -root.edgeRoot.outerPadding
            PathLine {
                x: frameShape.width + root.edgeRoot.outerPadding
                y: -root.edgeRoot.outerPadding
            }
            PathLine {
                x: frameShape.width + root.edgeRoot.outerPadding
                y: frameShape.height + root.edgeRoot.outerPadding
            }
            PathLine {
                x: -root.edgeRoot.outerPadding
                y: frameShape.height + root.edgeRoot.outerPadding
            }
            PathLine {
                x: -root.edgeRoot.outerPadding
                y: -root.edgeRoot.outerPadding
            }

            PathMove {
                x: framePath.innerLeft + framePath.r
                y: framePath.innerTop
            }
            PathLine {
                x: framePath.innerRight - framePath.r
                y: framePath.innerTop
            }
            PathArc {
                x: framePath.innerRight
                y: framePath.innerTop + framePath.r
                radiusX: framePath.r
                radiusY: framePath.r
                direction: PathArc.Clockwise
            }
            PathLine {
                x: framePath.innerRight
                y: framePath.innerBottom - framePath.r
            }
            PathArc {
                x: framePath.innerRight - framePath.r
                y: framePath.innerBottom
                radiusX: framePath.r
                radiusY: framePath.r
                direction: PathArc.Clockwise
            }
            PathLine {
                x: framePath.innerLeft + framePath.r
                y: framePath.innerBottom
            }
            PathArc {
                x: framePath.innerLeft
                y: framePath.innerBottom - framePath.r
                radiusX: framePath.r
                radiusY: framePath.r
                direction: PathArc.Clockwise
            }
            PathLine {
                x: framePath.innerLeft
                y: framePath.innerTop + framePath.r
            }
            PathArc {
                x: framePath.innerLeft + framePath.r
                y: framePath.innerTop
                radiusX: framePath.r
                radiusY: framePath.r
                direction: PathArc.Clockwise
            }
        }
    }
}
