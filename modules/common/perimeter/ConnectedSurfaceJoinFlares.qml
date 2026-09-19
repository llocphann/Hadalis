import QtQuick
import QtQuick.Shapes

// Exact Screen Edge inverse corners for direct popup/sidebar/dashboard joins.
//
// Caelestia renders border + panels in one SDF group, so their contact corners
// naturally inherit the border silhouette. Hadalis uses independent layer-shell
// surfaces; reproduce that contact deterministically by cloning the physical
// Screen Edge quarter-circle itself at every attachment endpoint.
//
// There is one canonical inverse top-left PathArc below. Every other orientation
// is only a mirror of that same path, so all contact corners stay mathematically
// identical to one another and share the same radius as ScreenEdges.qml.
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
        root.bodyItem?.height / 2 ?? 0))

    visible: root.reveal > 0.001 && root.radius > 0
        && (root.joinTop || root.joinBottom || root.joinLeft || root.joinRight)

    component Flare: Item {
        id: flare

        required property string flareCorner
        property color flareColor: root.fillColor

        // Existing endpoint names describe where the contact sits relative to
        // the body. Convert them to the actual inverse Screen Edge corner that
        // must be painted in that square.
        readonly property string inverseCorner:
            flareCorner === "topLeft" || flareCorner === "rightBottom"
                ? "topRight"
            : flareCorner === "topRight" || flareCorner === "leftBottom"
                ? "topLeft"
            : flareCorner === "bottomLeft" || flareCorner === "rightTop"
                ? "bottomRight"
            : "bottomLeft"

        readonly property bool mirrorX: inverseCorner.endsWith("Right")
        readonly property bool mirrorY: inverseCorner.startsWith("bottom")

        visible: width > 0 && height > 0

        Shape {
            id: cornerShape
            anchors.fill: parent
            antialiasing: true
            preferredRendererType: Shape.CurveRenderer

            transform: Scale {
                origin.x: cornerShape.width / 2
                origin.y: cornerShape.height / 2
                xScale: flare.mirrorX ? -1 : 1
                yScale: flare.mirrorY ? -1 : 1
            }

            // Canonical inverse top-left Screen Edge corner:
            // (0,0) -> (0,r) -> quarter arc -> (r,0) -> (0,0).
            // This is the same circular boundary used by the locked physical
            // frame, not a Bezier/ellipse approximation.
            ShapePath {
                fillColor: flare.flareColor
                strokeColor: "transparent"
                strokeWidth: 0
                startX: 0
                startY: 0

                PathLine {
                    x: 0
                    y: cornerShape.height
                }
                PathArc {
                    x: cornerShape.width
                    y: 0
                    radiusX: cornerShape.width
                    radiusY: cornerShape.height
                    direction: PathArc.Clockwise
                }
                PathLine {
                    x: 0
                    y: 0
                }
            }
        }
    }

    // Top attachment: popup body is below the Screen Edge.
    Flare {
        flareCorner: "topLeft"
        visible: root.joinTop && !root.joinLeft && root.radius > 0
        x: root.bodyOrigin.x - root.radius
        y: root.bodyOrigin.y
        width: root.radius
        height: root.radius
    }
    Flare {
        flareCorner: "topRight"
        visible: root.joinTop && !root.joinRight && root.radius > 0
        x: root.bodyOrigin.x + root.bodyItem.width
        y: root.bodyOrigin.y
        width: root.radius
        height: root.radius
    }

    // Bottom attachment: popup/dashboard body is above the Screen Edge.
    Flare {
        flareCorner: "bottomLeft"
        visible: root.joinBottom && !root.joinLeft && root.radius > 0
        x: root.bodyOrigin.x - root.radius
        y: root.bodyOrigin.y + root.bodyItem.height - root.radius
        width: root.radius
        height: root.radius
    }
    Flare {
        flareCorner: "bottomRight"
        visible: root.joinBottom && !root.joinRight && root.radius > 0
        x: root.bodyOrigin.x + root.bodyItem.width
        y: root.bodyOrigin.y + root.bodyItem.height - root.radius
        width: root.radius
        height: root.radius
    }

    // Left/right attachment uses the exact same four corners rotated by mirroring.
    Flare {
        flareCorner: "leftTop"
        visible: root.joinLeft && !root.joinTop && root.radius > 0
        x: root.bodyOrigin.x
        y: root.bodyOrigin.y - root.radius
        width: root.radius
        height: root.radius
    }
    Flare {
        flareCorner: "leftBottom"
        visible: root.joinLeft && !root.joinBottom && root.radius > 0
        x: root.bodyOrigin.x
        y: root.bodyOrigin.y + root.bodyItem.height
        width: root.radius
        height: root.radius
    }
    Flare {
        flareCorner: "rightTop"
        visible: root.joinRight && !root.joinTop && root.radius > 0
        x: root.bodyOrigin.x + root.bodyItem.width - root.radius
        y: root.bodyOrigin.y - root.radius
        width: root.radius
        height: root.radius
    }
    Flare {
        flareCorner: "rightBottom"
        visible: root.joinRight && !root.joinBottom && root.radius > 0
        x: root.bodyOrigin.x + root.bodyItem.width - root.radius
        y: root.bodyOrigin.y + root.bodyItem.height
        width: root.radius
        height: root.radius
    }
}
