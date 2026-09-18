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
        snapDown(outputRect.x + outputRect.width - effectiveScreenMargin)
            - snapUp(outputRect.x + effectiveScreenMargin))
    readonly property real availableHeight: Math.max(0,
        snapDown(outputRect.y + outputRect.height - effectiveScreenMargin)
            - snapUp(outputRect.y + effectiveScreenMargin))

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

    readonly property real anchorCenter: horizontal
        ? anchorRect.x + anchorRect.width / 2
        : anchorRect.y + anchorRect.height / 2
    readonly property real anchorTangentExtent: horizontal
        ? anchorRect.width : anchorRect.height
    readonly property real bodyTangentExtent: horizontal ? bodyRect.width : bodyRect.height
    readonly property real bodyTangentCenter: horizontal
        ? bodyRect.x + bodyRect.width / 2
        : bodyRect.y + bodyRect.height / 2

    // Every connected popup uses the same token-backed neck width. The source
    // control may be wider or narrower, but it must not resize the connector;
    // only an unusually narrow popup body is allowed to clamp it. The body-side
    // shoulder still flares by the shared outer radius so the join stays organic.
    readonly property real connectorSourceExtent: snapSize(Math.min(
        bodyTangentExtent,
        Math.max(0, connectorWidth)))
    readonly property real connectorBodyExtent: snapSize(Math.min(
        bodyTangentExtent,
        connectorSourceExtent + Math.max(0, outerRadius) * 2))

    readonly property real revealProgress: clamp(progress, 0, 1)
    // Preserve Caelestia's expressive-spatial overshoot for the actual motion.
    // Semantic visibility/input still consumes the clamped revealProgress, but
    // the body translation follows the animated scalar itself so the default
    // spatial curve can travel a few pixels past rest before settling.
    readonly property real motionProgress: Number.isFinite(Number(progress))
        ? Number(progress) : 0
    // Slide the complete body under the owning Bar/Screen Edge. The body never
    // resizes; its full cross-axis extent travels behind a fixed reveal boundary.
    readonly property real animatedTangentExtent: bodyTangentExtent
    readonly property real animatedCrossExtent: crossBodyExtent
    readonly property real animatedTangentCenter: bodyTangentCenter
    readonly property real animatedTangentStart: horizontal ? bodyRect.x : bodyRect.y
    readonly property real animationOffset: snap(
        (1 - motionProgress) * crossBodyExtent)
    // Caelestia panel wrappers translate only on the attachment axis. Tangent
    // placement remains fixed even when the resting body is corner-clamped;
    // this avoids a diagonal drift and keeps the connected shoulder stationary
    // relative to the source while the whole body slides under the owner.
    // Fixed viewport on the screen-facing side of the resting attachment seam.
    // Rendering inside this rect makes translated pixels disappear underneath
    // the Bar/Screen Edge instead of painting over that compositor surface.
    readonly property real attachmentBoundary: edge === "top"
        ? anchorRect.y + anchorRect.height
        : edge === "bottom" ? anchorRect.y
        : edge === "left" ? anchorRect.x + anchorRect.width
        : anchorRect.x
    readonly property rect revealClipRect: edge === "top"
        ? Qt.rect(outputRect.x, snap(attachmentBoundary),
            outputRect.width,
            Math.max(0, outputRect.y + outputRect.height - snap(attachmentBoundary)))
        : edge === "bottom"
            ? Qt.rect(outputRect.x, outputRect.y,
                outputRect.width,
                Math.max(0, snap(attachmentBoundary) - outputRect.y))
        : edge === "left"
            ? Qt.rect(snap(attachmentBoundary), outputRect.y,
                Math.max(0, outputRect.x + outputRect.width - snap(attachmentBoundary)),
                outputRect.height)
        : Qt.rect(outputRect.x, outputRect.y,
            Math.max(0, snap(attachmentBoundary) - outputRect.x),
            outputRect.height)

    readonly property rect animatedBodyRect: edge === "top"
        ? Qt.rect(snap(bodyRect.x),
            snap(bodyRect.y - animationOffset),
            bodyRect.width, bodyRect.height)
        : edge === "bottom"
            ? Qt.rect(snap(bodyRect.x),
                snap(bodyRect.y + animationOffset),
                bodyRect.width, bodyRect.height)
        : edge === "left"
            ? Qt.rect(snap(bodyRect.x - animationOffset),
                snap(bodyRect.y),
                bodyRect.width, bodyRect.height)
        : Qt.rect(snap(bodyRect.x + animationOffset),
            snap(bodyRect.y),
            bodyRect.width, bodyRect.height)

    readonly property real connectorTangentExtent: connectorBodyExtent

    function connectorExtentForBody(body) {
        const bodyExtent = root.horizontal ? body.width : body.height
        return root.snapSize(Math.min(
            root.connectorBodyExtent,
            Math.max(root.connectorSourceExtent, bodyExtent)))
    }

    function connectorCenterForBody(body, extent) {
        const bodyStart = root.horizontal ? body.x : body.y
        const bodyExtent = root.horizontal ? body.width : body.height
        if (extent <= 0 || bodyExtent <= 0)
            return root.snap(root.anchorCenter)
        return root.snapWithin(root.anchorCenter,
            bodyStart + extent / 2,
            bodyStart + bodyExtent - extent / 2)
    }

    function connectorRectForBody(body) {
        const extent = root.connectorExtentForBody(body)
        const center = root.connectorCenterForBody(body, extent)
        const overlap = root.effectiveSeamOverlap
        if (extent <= 0)
            return Qt.rect(0, 0, 0, 0)

        if (root.edge === "top") {
            const x = root.snap(center - extent / 2)
            const y = root.snap(root.anchorRect.y + root.anchorRect.height - overlap)
            const end = root.snap(body.y + overlap)
            return Qt.rect(x, y, extent, root.snapSize(end - y))
        }
        if (root.edge === "bottom") {
            const x = root.snap(center - extent / 2)
            const y = root.snap(body.y + body.height - overlap)
            const end = root.snap(root.anchorRect.y + overlap)
            return Qt.rect(x, y, extent, root.snapSize(end - y))
        }
        if (root.edge === "left") {
            const x = root.snap(root.anchorRect.x + root.anchorRect.width - overlap)
            const y = root.snap(center - extent / 2)
            const end = root.snap(body.x + overlap)
            return Qt.rect(x, y, root.snapSize(end - x), extent)
        }
        const x = root.snap(body.x + body.width - overlap)
        const y = root.snap(center - extent / 2)
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

    function intersectRect(a, b) {
        const left = Math.max(a.x, b.x)
        const top = Math.max(a.y, b.y)
        const right = Math.min(a.x + a.width, b.x + b.width)
        const bottom = Math.min(a.y + a.height, b.y + b.height)
        return Qt.rect(left, top,
            Math.max(0, right - left), Math.max(0, bottom - top))
    }

    // Input follows only the visible body segment during slide-under motion.
    readonly property rect visibleBodyRect:
        intersectRect(animatedBodyRect, revealClipRect)
    readonly property rect blurRect: {
        const expansion = Math.max(0, blurExpansion)
        const left = snapDown(visualBounds.x - expansion)
        const top = snapDown(visualBounds.y - expansion)
        const right = snapUp(visualBounds.x + visualBounds.width + expansion)
        const bottom = snapUp(visualBounds.y + visualBounds.height + expansion)
        return Qt.rect(left, top, Math.max(0, right - left), Math.max(0, bottom - top))
    }
}
