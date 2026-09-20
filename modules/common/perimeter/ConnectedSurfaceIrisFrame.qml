pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects

// ii production connected-popup renderer.
//
// The owner Bar/Screen Edge remains painted by its Top-layer window. This
// Overlay item keeps those owner rectangles only as iRiS SDF records, then
// clips field/input/shadow paint to the popup side of every ownership boundary.
// No helper window or per-corner patch geometry is introduced.
Item {
    id: root

    required property var geometry
    property color fillColor: "white"
    property color borderColor: "transparent"
    property real borderWidth: 0
    property real fuseDepth: PerimeterTokens.irisFuseDepth
    property real externalFrameThickness: 10
    property real aaReach: 2

    property bool joinTop: false
    property bool joinBottom: false
    property bool joinLeft: false
    property bool joinRight: false

    property bool shadowEnabled: false
    property real shadowExtent: 0
    property color shadowColor: "transparent"

    property bool hoverEnabled: false
    readonly property bool bodyHovered: bodyHover.hovered
    readonly property Item bodyItem: bodyProxy
    readonly property bool shaderCompiled: field.shaderCompiled
    readonly property string shaderLog: field.shaderLog

    readonly property bool horizontal:
        root.geometry?.edge === "top" || root.geometry?.edge === "bottom"
    readonly property rect output: root.geometry?.outputRect
        ?? Qt.rect(0, 0, root.width, root.height)
    readonly property rect body: root.geometry?.animatedBodyRect
        ?? Qt.rect(0, 0, 0, 0)
    readonly property real frameThickness:
        Math.max(0, Number(root.externalFrameThickness ?? 0))
    readonly property real fuse: Math.max(0, Number(root.fuseDepth ?? 0))
    readonly property bool tangentStartJoined:
        root.horizontal ? root.joinLeft : root.joinTop
    readonly property bool tangentEndJoined:
        root.horizontal ? root.joinRight : root.joinBottom

    visible: root.geometry?.valid === true
        && Number(root.geometry?.revealProgress ?? root.geometry?.progress ?? 0) > 0

    function clipExternalOwners(raw) {
        let left = Math.max(root.output.x, raw.x)
        let top = Math.max(root.output.y, raw.y)
        let right = Math.min(root.output.x + root.output.width,
            raw.x + raw.width)
        let bottom = Math.min(root.output.y + root.output.height,
            raw.y + raw.height)

        const seam = Number(root.geometry?.attachmentBoundary ?? 0)
        if (root.geometry?.edge === "top")
            top = Math.max(top, seam)
        else if (root.geometry?.edge === "bottom")
            bottom = Math.min(bottom, seam)
        else if (root.geometry?.edge === "left")
            left = Math.max(left, seam)
        else if (root.geometry?.edge === "right")
            right = Math.min(right, seam)

        if (root.horizontal && root.tangentStartJoined)
            left = Math.max(left, root.output.x + root.frameThickness)
        if (root.horizontal && root.tangentEndJoined)
            right = Math.min(right,
                root.output.x + root.output.width - root.frameThickness)
        if (!root.horizontal && root.tangentStartJoined)
            top = Math.max(top, root.output.y + root.frameThickness)
        if (!root.horizontal && root.tangentEndJoined)
            bottom = Math.min(bottom,
                root.output.y + root.output.height - root.frameThickness)

        return Qt.rect(left, top,
            Math.max(0, right - left), Math.max(0, bottom - top))
    }

    readonly property rect rawPaintBounds: {
        const b = root.body
        const tangentReach = root.fuse + root.aaReach
        const freeReach = root.aaReach

        if (root.geometry?.edge === "top")
            return Qt.rect(b.x - tangentReach, b.y,
                b.width + tangentReach * 2, b.height + freeReach)
        if (root.geometry?.edge === "bottom")
            return Qt.rect(b.x - tangentReach, b.y - freeReach,
                b.width + tangentReach * 2, b.height + freeReach)
        if (root.geometry?.edge === "left")
            return Qt.rect(b.x, b.y - tangentReach,
                b.width + freeReach, b.height + tangentReach * 2)
        return Qt.rect(b.x - freeReach, b.y - tangentReach,
            b.width + freeReach, b.height + tangentReach * 2)
    }

    readonly property rect paintBounds:
        root.clipExternalOwners(root.rawPaintBounds)
    // Use the same owner exclusion for compositor input. At tangent clamps the
    // SDF body deliberately welds underneath the physical Screen Edge.
    readonly property rect visibleBodyRect:
        root.clipExternalOwners(root.body)

    readonly property rect ownerShapeRect: {
        const a = root.geometry?.anchorRect ?? Qt.rect(0, 0, 0, 0)
        const pad = root.fuse * 2
        if (root.geometry?.edge === "top" || root.geometry?.edge === "bottom")
            return Qt.rect(root.output.x - pad, a.y,
                root.output.width + pad * 2, a.height)
        return Qt.rect(a.x, root.output.y - pad,
            a.width, root.output.height + pad * 2)
    }

    readonly property var ownerShape: ({
        x: root.ownerShapeRect.x,
        y: root.ownerShapeRect.y,
        width: root.ownerShapeRect.width,
        height: root.ownerShapeRect.height,
        radius: 0,
        fuse: 0,
        id: "owner"
    })

    readonly property var frameStartShape: root.horizontal
        ? ({
            x: root.output.x,
            y: root.output.y - root.fuse * 2,
            width: root.frameThickness,
            height: root.output.height + root.fuse * 4,
            radius: 0,
            fuse: 0,
            id: "frame-start"
        })
        : ({
            x: root.output.x - root.fuse * 2,
            y: root.output.y,
            width: root.output.width + root.fuse * 4,
            height: root.frameThickness,
            radius: 0,
            fuse: 0,
            id: "frame-start"
        })

    readonly property var frameEndShape: root.horizontal
        ? ({
            x: root.output.x + root.output.width - root.frameThickness,
            y: root.output.y - root.fuse * 2,
            width: root.frameThickness,
            height: root.output.height + root.fuse * 4,
            radius: 0,
            fuse: 0,
            id: "frame-end"
        })
        : ({
            x: root.output.x - root.fuse * 2,
            y: root.output.y + root.output.height - root.frameThickness,
            width: root.output.width + root.fuse * 4,
            height: root.frameThickness,
            radius: 0,
            fuse: 0,
            id: "frame-end"
        })

    readonly property var popupPrimaryJoins: {
        const joins = ["owner"]
        if (root.tangentStartJoined)
            joins.push("frame-start")
        else if (root.tangentEndJoined)
            joins.push("frame-end")
        return joins
    }

    readonly property var popupShape: ({
        x: root.body.x,
        y: root.body.y,
        width: root.body.width,
        height: root.body.height,
        radius: Number(root.geometry?.outerRadius ?? 0),
        fuse: root.fuse,
        id: "popup",
        joins: root.popupPrimaryJoins
    })

    // The shader ABI permits two owner relations per shape. A popup can
    // legitimately span both tangent edges as well as its primary owner, so a
    // duplicate zero-material SDF record carries only the third relation.
    readonly property bool needsEndJoinAux:
        root.tangentStartJoined && root.tangentEndJoined
    readonly property var popupEndJoinShape: root.needsEndJoinAux
        ? ({
            x: root.body.x,
            y: root.body.y,
            width: root.body.width,
            height: root.body.height,
            radius: Number(root.geometry?.outerRadius ?? 0),
            fuse: root.fuse,
            id: "popup-end-join",
            joins: ["frame-end"]
        })
        : ({
            x: 0, y: 0, width: 0, height: 0,
            radius: 0, fuse: 0, id: "popup-end-join"
        })

    readonly property real shadowTextureExtent:
        Math.max(0, root.shadowExtent) + 2
    readonly property rect rawShadowBounds: Qt.rect(
        root.body.x - root.shadowTextureExtent,
        root.body.y - root.shadowTextureExtent,
        root.body.width + root.shadowTextureExtent * 2,
        root.body.height + root.shadowTextureExtent * 2)
    readonly property rect shadowPaintBounds:
        root.clipExternalOwners(root.rawShadowBounds)

    Item {
        id: shadowTextureSource
        z: -100
        visible: root.shadowEnabled
        x: root.rawShadowBounds.x
        y: root.rawShadowBounds.y
        width: root.rawShadowBounds.width
        height: root.rawShadowBounds.height
        clip: true

        RectangularShadow {
            x: root.shadowTextureExtent
            y: root.shadowTextureExtent
            width: root.body.width
            height: root.body.height
            radius: Number(root.geometry?.outerRadius ?? 0)
                + Math.max(0, root.shadowExtent) * 0.75
            blur: Math.max(0, root.shadowExtent)
            spread: 0
            offset: Qt.vector2d(0, 0)
            color: root.shadowColor
            cached: false
        }
    }

    ShaderEffectSource {
        id: isolatedShadow
        z: 0
        visible: root.shadowEnabled
            && root.shadowPaintBounds.width > 0
            && root.shadowPaintBounds.height > 0
        x: root.shadowPaintBounds.x
        y: root.shadowPaintBounds.y
        width: root.shadowPaintBounds.width
        height: root.shadowPaintBounds.height
        sourceItem: shadowTextureSource
        sourceRect: Qt.rect(
            root.shadowPaintBounds.x - root.rawShadowBounds.x,
            root.shadowPaintBounds.y - root.rawShadowBounds.y,
            root.shadowPaintBounds.width,
            root.shadowPaintBounds.height)
        hideSource: true
        live: true
        recursive: false
        smooth: true
    }

    ConnectedSurfaceIrisField {
        id: field
        z: 1
        width: root.width
        height: root.height
        paintBounds: root.paintBounds
        shapes: [
            root.ownerShape,
            root.frameStartShape,
            root.frameEndShape,
            root.popupShape,
            root.popupEndJoinShape
        ]
        tint: root.fillColor
        rimColor: root.borderColor
        rimWidth: root.borderWidth
        smoothing: root.fuse
    }

    // Geometry-only body proxy for hover ownership and the compositor input
    // region. It paints nothing; the iRiS field above owns the silhouette.
    Item {
        id: bodyProxy
        z: 2
        x: root.body.x
        y: root.body.y
        width: root.body.width
        height: root.body.height
        visible: root.visible && width > 0 && height > 0

        HoverHandler {
            id: bodyHover
            enabled: root.hoverEnabled && bodyProxy.visible
        }
    }
}
