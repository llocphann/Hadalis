import QtQuick
import qs.modules.common.widgets

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
    // Caelestia moves one already-formed blob through a clipped viewport; the
    // corner geometry itself does not grow from zero during the reveal. Keep
    // the shoulder at its full radius and let the translated body + clip own
    // the animation. Scaling the radius by progress made the flare disappear
    // for most of the transition and could leave it visually absent after a
    // rapid reverse.
    readonly property real radius: Math.max(0, Math.min(
        root.flareRadius,
        root.bodyItem?.width / 2 ?? 0,
        root.bodyItem?.height / 2 ?? 0))

    visible: root.reveal > 0.001 && root.radius > 0
        && (root.joinTop || root.joinBottom || root.joinLeft || root.joinRight)

    // Reuse the same inverse-corner primitive as the Hug Bar. This removes a
    // second Canvas implementation and guarantees identical shoulders for Bar,
    // popup, Settings, Sidebar and Screen Edge connected surfaces.
    component Flare: RoundCorner {
        required property string corner
        property color flareColor: root.fillColor
        property real r: root.radius

        width: r
        height: r
        implicitSize: Math.max(1, Math.round(r))
        color: flareColor
        visible: r > 0

        corner: switch (corner) {
            case "topLeft": return RoundCorner.CornerEnum.TopLeft
            case "topRight": return RoundCorner.CornerEnum.TopRight
            case "bottomLeft": return RoundCorner.CornerEnum.BottomLeft
            case "bottomRight": return RoundCorner.CornerEnum.BottomRight
            // Vertical joins use the same four silhouettes, rotated by which
            // two solid edges meet inside the r×r shoulder square.
            case "leftTop": return RoundCorner.CornerEnum.BottomRight
            case "leftBottom": return RoundCorner.CornerEnum.TopRight
            case "rightTop": return RoundCorner.CornerEnum.BottomLeft
            case "rightBottom": return RoundCorner.CornerEnum.TopLeft
            default: return RoundCorner.CornerEnum.TopLeft
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
