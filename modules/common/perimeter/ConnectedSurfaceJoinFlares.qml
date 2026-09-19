import QtQuick

// CONNECTED-SURFACE-OUTWARD-FLARE-LOCK (maintainer clarified 2026-09-19):
// Contact corners belong to the popup/sidebar/dashboard surface, never to the
// locked physical Screen Edge/Bar renderer. Joined body corners stay square.
// ConnectedSurfaceContactFlare owns one canonical circular-smooth-union lobe;
// this item only places and mirror/rotates that primitive for all 8 endpoints.
//
// The canonical curve is the local smin=0 silhouette used by Caelestia's
// BlobGroup when a panel BlobRect meets the inverted border field. Hadalis
// cannot share one SDF across separate layer-shell windows, so it renders only
// the excess union lobe on the connected-surface side.
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

    // Endpoint indices:
    // 0 top-left, 1 top-right, 2 bottom-left, 3 bottom-right,
    // 4 left-top, 5 left-bottom, 6 right-top, 7 right-bottom.
    function flareVisible(index) {
        switch (index) {
        case 0: return root.joinTop && !root.joinLeft
        case 1: return root.joinTop && !root.joinRight
        case 2: return root.joinBottom && !root.joinLeft
        case 3: return root.joinBottom && !root.joinRight
        case 4: return root.joinLeft && !root.joinTop
        case 5: return root.joinLeft && !root.joinBottom
        case 6: return root.joinRight && !root.joinTop
        case 7: return root.joinRight && !root.joinBottom
        default: return false
        }
    }

    function flareX(index) {
        const x = root.bodyOrigin.x
        const w = root.bodyItem?.width ?? 0
        switch (index) {
        case 0:
        case 2:
            return x - root.radius
        case 1:
        case 3:
            return x + w
        case 4:
        case 5:
            return x
        case 6:
        case 7:
            return x + w - root.radius
        default:
            return x
        }
    }

    function flareY(index) {
        const y = root.bodyOrigin.y
        const h = root.bodyItem?.height ?? 0
        switch (index) {
        case 0:
        case 1:
            return y
        case 2:
        case 3:
            return y + h - root.radius
        case 4:
        case 6:
            return y - root.radius
        case 5:
        case 7:
            return y + h
        default:
            return y
        }
    }

    // Canonical orientation has seam=top and body=right. These D4 transforms
    // produce every other endpoint without duplicating path math.
    function flareQuarterTurns(index) {
        switch (index) {
        case 0:
        case 1:
            return 0
        case 2:
        case 3:
            return 2
        case 4:
        case 5:
            return 3
        case 6:
        case 7:
            return 1
        default:
            return 0
        }
    }

    function flareMirrored(index) {
        return index === 1 || index === 2 || index === 4 || index === 7
    }

    Repeater {
        model: 8

        delegate: ConnectedSurfaceContactFlare {
            x: root.flareX(index)
            y: root.flareY(index)
            width: root.radius
            height: root.radius
            visible: root.flareVisible(index)
            fillColor: root.fillColor
            quarterTurns: root.flareQuarterTurns(index)
            mirrored: root.flareMirrored(index)
        }
    }
}
