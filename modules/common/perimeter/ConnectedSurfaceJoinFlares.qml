import QtQuick
import qs.modules.common.widgets

// Concave union shoulders for direct Bar/Screen Edge attachments.
//
// Caelestia gets this silhouette from its blob-union renderer. Hadalis keeps
// its connected-surface architecture and composes the same tangent shoulder
// from the shared inverse-corner primitive. No connector/stem is drawn: each
// flare only fills the outside corner between already-touching surfaces.
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

    // Shadow is structural connected chrome and follows the exact same live
    // Screen Edge settings as Bar, popup body, Sidebar, Dashboard and Settings.
    property bool shadowEnabled: false
    property real shadowExtent: 0
    property color shadowColor: "transparent"

    readonly property real reveal: Math.max(0, Math.min(1, root.progress))
    readonly property point bodyOrigin: root.bodyItem
        ? root.bodyItem.mapToItem(root, 0, 0) : Qt.point(0, 0)
    // Keep the shoulder fully formed while the body slides under its owner.
    // Growing/shrinking the corner during reveal is unlike Caelestia's blob
    // motion and makes the flare disappear during rapid open/close reversals.
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
        property real r: root.radius

        readonly property int cornerEnum: switch (flareCorner) {
            // The flare is outside the body endpoint, so the inverse corner is
            // the opposite tangent orientation from the body-corner label.
            case "topLeft": return RoundCorner.CornerEnum.TopRight
            case "topRight": return RoundCorner.CornerEnum.TopLeft
            case "bottomLeft": return RoundCorner.CornerEnum.BottomRight
            case "bottomRight": return RoundCorner.CornerEnum.BottomLeft
            case "leftTop": return RoundCorner.CornerEnum.BottomLeft
            case "leftBottom": return RoundCorner.CornerEnum.TopLeft
            case "rightTop": return RoundCorner.CornerEnum.BottomRight
            case "rightBottom": return RoundCorner.CornerEnum.TopRight
            default: return RoundCorner.CornerEnum.TopLeft
        }

        width: r
        height: r
        visible: r > 0

        // Keep the flare itself dependency-free. The connected body owns the
        // shared Screen Edge shadow; using a separate unresolved corner-shadow
        // primitive here makes the entire shell fail QML type resolution.
        RoundCorner {
            z: 1
            anchors.fill: parent
            implicitSize: Math.max(1, Math.round(flare.r))
            color: flare.flareColor
            corner: flare.cornerEnum
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
