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

    readonly property bool horizontal: edge === "top" || edge === "bottom"
    readonly property string inwardDirection: PerimeterTopology.inwardDirectionForEdge(edge)
    readonly property bool valid: PerimeterTopology.edges.includes(edge) && bodySize.width > 0 && bodySize.height > 0

    function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)) }
    function snap(v) {
        const scale = Math.max(1, devicePixelRatio)
        return Math.round(v * scale) / scale
    }

    readonly property real tangentStart: {
        const anchorStart = horizontal ? anchorRect.x : anchorRect.y
        const anchorExtent = horizontal ? anchorRect.width : anchorRect.height
        const bodyExtent = horizontal ? bodySize.width : bodySize.height
        let wanted = alignment === "start" ? anchorStart
            : alignment === "end" ? anchorStart + anchorExtent - bodyExtent
            : anchorStart + anchorExtent / 2 - bodyExtent / 2
        const minimum = (horizontal ? outputRect.x : outputRect.y) + screenMargin
        const maximum = (horizontal ? outputRect.x + outputRect.width - bodySize.width
            : outputRect.y + outputRect.height - bodySize.height) - screenMargin
        return snap(clamp(wanted, minimum, Math.max(minimum, maximum)))
    }

    readonly property real bodyCrossStart: snap(edge === "top"
        ? Math.min(anchorRect.y + anchorRect.height + connectorLength - seamOverlap,
            outputRect.y + outputRect.height - screenMargin - bodySize.height)
        : edge === "bottom"
            ? Math.max(anchorRect.y - bodySize.height - connectorLength + seamOverlap,
                outputRect.y + screenMargin)
        : edge === "left"
            ? Math.min(anchorRect.x + anchorRect.width + connectorLength - seamOverlap,
                outputRect.x + outputRect.width - screenMargin - bodySize.width)
        : Math.max(anchorRect.x - bodySize.width - connectorLength + seamOverlap,
            outputRect.x + screenMargin))

    readonly property rect bodyRect: horizontal
        ? Qt.rect(tangentStart, bodyCrossStart, snap(bodySize.width), snap(bodySize.height))
        : Qt.rect(bodyCrossStart, tangentStart, snap(bodySize.width), snap(bodySize.height))

    readonly property real anchorCenter: horizontal
        ? anchorRect.x + anchorRect.width / 2
        : anchorRect.y + anchorRect.height / 2
    readonly property real bodyTangentExtent: horizontal ? bodyRect.width : bodyRect.height
    readonly property real connectorCenter: snap(clamp(anchorCenter,
        tangentStart + connectorWidth / 2,
        tangentStart + bodyTangentExtent - connectorWidth / 2))

    readonly property rect connectorRect: {
        if (edge === "top") {
            const y = anchorRect.y + anchorRect.height - seamOverlap
            return Qt.rect(connectorCenter - connectorWidth / 2, y, connectorWidth,
                Math.max(0, bodyRect.y - y + seamOverlap))
        }
        if (edge === "bottom") {
            const y = bodyRect.y + bodyRect.height - seamOverlap
            return Qt.rect(connectorCenter - connectorWidth / 2, y, connectorWidth,
                Math.max(0, anchorRect.y + seamOverlap - y))
        }
        if (edge === "left") {
            const x = anchorRect.x + anchorRect.width - seamOverlap
            return Qt.rect(x, connectorCenter - connectorWidth / 2,
                Math.max(0, bodyRect.x - x + seamOverlap), connectorWidth)
        }
        const x = bodyRect.x + bodyRect.width - seamOverlap
        return Qt.rect(x, connectorCenter - connectorWidth / 2,
            Math.max(0, anchorRect.x + seamOverlap - x), connectorWidth)
    }

    readonly property point connectorCenterPoint: Qt.point(
        connectorRect.x + connectorRect.width / 2,
        connectorRect.y + connectorRect.height / 2)
    readonly property rect visualBounds: Qt.rect(
        Math.min(bodyRect.x, connectorRect.x),
        Math.min(bodyRect.y, connectorRect.y),
        Math.max(bodyRect.x + bodyRect.width, connectorRect.x + connectorRect.width) - Math.min(bodyRect.x, connectorRect.x),
        Math.max(bodyRect.y + bodyRect.height, connectorRect.y + connectorRect.height) - Math.min(bodyRect.y, connectorRect.y))
    readonly property rect blurRect: Qt.rect(
        visualBounds.x - blurExpansion,
        visualBounds.y - blurExpansion,
        visualBounds.width + blurExpansion * 2,
        visualBounds.height + blurExpansion * 2)
    readonly property real animationOffset: (1 - clamp(progress, 0, 1)) * connectorLength
    readonly property real offsetX: edge === "left" ? -animationOffset : edge === "right" ? animationOffset : 0
    readonly property real offsetY: edge === "top" ? -animationOffset : edge === "bottom" ? animationOffset : 0
}
