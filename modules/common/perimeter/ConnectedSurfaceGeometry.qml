import QtQuick

QtObject {
    id: root

    property string edge: "top"
    property string alignment: "center"
    property rect outputRect: Qt.rect(0, 0, 1920, 1080)
    property rect anchorRect: Qt.rect(0, 0, 0, 0)
    property size bodySize: Qt.size(360, 300)
    property real connectorWidth: PerimeterTokens.connectorWidth
    property real connectorLength: PerimeterTokens.connectorLength
    property real outerRadius: PerimeterTokens.outerRadius
    property real neckRadius: PerimeterTokens.neckRadius
    property real screenMargin: PerimeterTokens.screenMargin
    property real seamOverlap: PerimeterTokens.seamOverlap
    property real borderWidth: PerimeterTokens.borderWidth
    property real blurExpansion: PerimeterTokens.blurExpansion
    property real progress: 1
    property real devicePixelRatio: 1

    function clamp(v, lo, hi) {
        return Math.max(lo, Math.min(hi, v))
    }

    function pixelScale() {
        return devicePixelRatio > 0 ? devicePixelRatio : 1
    }

    function snap(v) {
        const scale = root.pixelScale()
        return Math.round(v * scale) / scale
    }

    function snapDown(v) {
        const scale = root.pixelScale()
        return Math.floor(v * scale) / scale
    }

    function snapUp(v) {
        const scale = root.pixelScale()
        return Math.ceil(v * scale) / scale
    }

    function snapSize(v) {
        return Math.max(0, root.snap(Math.max(0, v)))
    }

    function snapSizeDown(v) {
        return Math.max(0, root.snapDown(Math.max(0, v)))
    }

    function snapWithin(v, lo, hi) {
        const lower = root.snapUp(lo)
        const upper = root.snapDown(hi)
        if (upper >= lower)
            return root.clamp(root.snap(v), lower, upper)
        return root.snap(root.clamp(v, lo, hi))
    }

    function numberFinite(value) {
        return Number.isFinite(Number(value))
    }

    function rectHasArea(rect) {
        return rect
            && root.numberFinite(rect.x)
            && root.numberFinite(rect.y)
            && root.numberFinite(rect.width)
            && root.numberFinite(rect.height)
            && rect.width > 0
            && rect.height > 0
    }

    function unionRect(a, b) {
        if (!root.rectHasArea(a))
            return b
        if (!root.rectHasArea(b))
            return a
        const left = Math.min(a.x, b.x)
        const top = Math.min(a.y, b.y)
        const right = Math.max(a.x + a.width, b.x + b.width)
        const bottom = Math.max(a.y + a.height, b.y + b.height)
        return Qt.rect(left, top, Math.max(0, right - left), Math.max(0, bottom - top))
    }

    readonly property bool horizontal: edge === "top" || edge === "bottom"
    readonly property bool alignmentValid: ["start", "center", "end"].includes(alignment)
    readonly property string inwardDirection: PerimeterTopology.inwardDirectionForEdge(edge)
    readonly property real effectiveScreenMargin: Math.max(0, screenMargin)
    readonly property real effectiveConnectorLength: Math.max(0, connectorLength)
    readonly property real effectiveSeamOverlap: Math.max(0, seamOverlap)
    readonly property real availableWidth: Math.max(0,
        outputRect.width - effectiveScreenMargin * 2)
    readonly property real availableHeight: Math.max(0,
        outputRect.height - effectiveScreenMargin * 2)

    // Preserve the source-to-body gap while clamping: when a requested surface
    // is too large for the inward side of its anchor, shrink it instead of
    // shifting it back through the anchor/source item.
    readonly property real inwardCrossCapacity: Math.max(0,
        edge === "top"
            ? outputRect.y + outputRect.height - effectiveScreenMargin
                - (anchorRect.y + anchorRect.height + effectiveConnectorLength - effectiveSeamOverlap)
        : edge === "bottom"
            ? anchorRect.y - effectiveConnectorLength + effectiveSeamOverlap
                - (outputRect.y + effectiveScreenMargin)
        : edge === "left"
            ? outputRect.x + outputRect.width - effectiveScreenMargin
                - (anchorRect.x + anchorRect.width + effectiveConnectorLength - effectiveSeamOverlap)
        : anchorRect.x - effectiveConnectorLength + effectiveSeamOverlap
            - (outputRect.x + effectiveScreenMargin))
    readonly property real maximumBodyWidth: horizontal
        ? availableWidth : Math.min(availableWidth, inwardCrossCapacity)
    readonly property real maximumBodyHeight: horizontal
        ? Math.min(availableHeight, inwardCrossCapacity) : availableHeight
    readonly property size clampedBodySize: Qt.size(
        snapSizeDown(Math.min(Math.max(0, bodySize.width), maximumBodyWidth)),
        snapSizeDown(Math.min(Math.max(0, bodySize.height), maximumBodyHeight)))
    readonly property bool bodyWasClamped:
        clampedBodySize.width !== snapSizeDown(bodySize.width)
        || clampedBodySize.height !== snapSizeDown(bodySize.height)
    readonly property bool valid: PerimeterTopology.edges.includes(edge)
        && alignmentValid
        && rectHasArea(outputRect)
        && rectHasArea(anchorRect)
        && clampedBodySize.width > 0 && clampedBodySize.height > 0

    readonly property real tangentBodyExtent: horizontal
        ? clampedBodySize.width : clampedBodySize.height
    readonly property real tangentOutputStart: horizontal ? outputRect.x : outputRect.y
    readonly property real tangentOutputExtent: horizontal ? outputRect.width : outputRect.height
    readonly property real tangentMinimum: tangentOutputStart + effectiveScreenMargin
    readonly property real tangentMaximum: tangentOutputStart + tangentOutputExtent
        - effectiveScreenMargin - tangentBodyExtent

    readonly property real tangentStart: {
        const anchorStart = horizontal ? anchorRect.x : anchorRect.y
        const anchorExtent = horizontal ? anchorRect.width : anchorRect.height
        let wanted = alignment === "start" ? anchorStart
            : alignment === "end" ? anchorStart + anchorExtent - tangentBodyExtent
            : anchorStart + anchorExtent / 2 - tangentBodyExtent / 2
        return snapWithin(wanted, tangentMinimum,
            Math.max(tangentMinimum, tangentMaximum))
    }

    readonly property real crossBodyExtent: horizontal
        ? clampedBodySize.height : clampedBodySize.width
    readonly property real crossOutputStart: horizontal ? outputRect.y : outputRect.x
    readonly property real crossOutputExtent: horizontal ? outputRect.height : outputRect.width
    readonly property real crossMinimum: crossOutputStart + effectiveScreenMargin
    readonly property real crossMaximum: crossOutputStart + crossOutputExtent
        - effectiveScreenMargin - crossBodyExtent
    readonly property real wantedBodyCrossStart: edge === "top"
        ? anchorRect.y + anchorRect.height + effectiveConnectorLength - effectiveSeamOverlap
        : edge === "bottom"
            ? anchorRect.y - clampedBodySize.height - effectiveConnectorLength + effectiveSeamOverlap
        : edge === "left"
            ? anchorRect.x + anchorRect.width + effectiveConnectorLength - effectiveSeamOverlap
        : anchorRect.x - clampedBodySize.width - effectiveConnectorLength + effectiveSeamOverlap
    readonly property real bodyCrossStart: snapWithin(wantedBodyCrossStart,
        crossMinimum, Math.max(crossMinimum, crossMaximum))

    // Resting body geometry. Consumers rendering an animated surface should use
    // animatedBodyRect so the shared geometry remains the single visual authority.
    readonly property rect bodyRect: horizontal
        ? Qt.rect(tangentStart, bodyCrossStart,
            clampedBodySize.width, clampedBodySize.height)
        : Qt.rect(bodyCrossStart, tangentStart,
            clampedBodySize.width, clampedBodySize.height)

    readonly property real animationOffset: snap((1 - clamp(progress, 0, 1))
        * effectiveConnectorLength)
    readonly property real offsetX: edge === "left" ? -animationOffset
        : edge === "right" ? animationOffset : 0
    readonly property real offsetY: edge === "top" ? -animationOffset
        : edge === "bottom" ? animationOffset : 0
    readonly property rect animatedBodyRect: Qt.rect(
        snap(bodyRect.x + offsetX),
        snap(bodyRect.y + offsetY),
        bodyRect.width,
        bodyRect.height)

    readonly property real anchorCenter: horizontal
        ? anchorRect.x + anchorRect.width / 2
        : anchorRect.y + anchorRect.height / 2
    readonly property real bodyTangentExtent: horizontal ? bodyRect.width : bodyRect.height
    readonly property real connectorTangentExtent: snapSize(Math.min(
        Math.max(0, connectorWidth), bodyTangentExtent))
    readonly property real connectorCenter: connectorTangentExtent > 0
        ? snapWithin(anchorCenter,
            tangentStart + connectorTangentExtent / 2,
            tangentStart + bodyTangentExtent - connectorTangentExtent / 2)
        : snap(tangentStart)

    function connectorRectForBody(body) {
        const extent = root.connectorTangentExtent
        const overlap = root.effectiveSeamOverlap
        if (extent <= 0)
            return Qt.rect(0, 0, 0, 0)

        if (root.edge === "top") {
            const x = root.snap(root.connectorCenter - extent / 2)
            const y = root.snap(root.anchorRect.y + root.anchorRect.height - overlap)
            const end = root.snap(body.y + overlap)
            return Qt.rect(x, y, extent, root.snapSize(end - y))
        }
        if (root.edge === "bottom") {
            const x = root.snap(root.connectorCenter - extent / 2)
            const y = root.snap(body.y + body.height - overlap)
            const end = root.snap(root.anchorRect.y + overlap)
            return Qt.rect(x, y, extent, root.snapSize(end - y))
        }
        if (root.edge === "left") {
            const x = root.snap(root.anchorRect.x + root.anchorRect.width - overlap)
            const y = root.snap(root.connectorCenter - extent / 2)
            const end = root.snap(body.x + overlap)
            return Qt.rect(x, y, root.snapSize(end - x), extent)
        }
        const x = root.snap(body.x + body.width - overlap)
        const y = root.snap(root.connectorCenter - extent / 2)
        const end = root.snap(root.anchorRect.x + overlap)
        return Qt.rect(x, y, root.snapSize(end - x), extent)
    }

    // The live connector keeps its source end fixed at anchorRect while its body
    // end follows animatedBodyRect, so it never detaches during enter/exit motion.
    readonly property rect restConnectorRect: connectorRectForBody(bodyRect)
    readonly property rect connectorRect: connectorRectForBody(animatedBodyRect)
    readonly property point connectorCenterPoint: Qt.point(
        connectorRect.x + connectorRect.width / 2,
        connectorRect.y + connectorRect.height / 2)

    readonly property rect restVisualBounds: unionRect(bodyRect, restConnectorRect)
    readonly property rect visualBounds: unionRect(animatedBodyRect, connectorRect)
    readonly property rect blurRect: {
        const expansion = Math.max(0, blurExpansion)
        const left = snapDown(visualBounds.x - expansion)
        const top = snapDown(visualBounds.y - expansion)
        const right = snapUp(visualBounds.x + visualBounds.width + expansion)
        const bottom = snapUp(visualBounds.y + visualBounds.height + expansion)
        return Qt.rect(left, top, Math.max(0, right - left), Math.max(0, bottom - top))
    }
}
