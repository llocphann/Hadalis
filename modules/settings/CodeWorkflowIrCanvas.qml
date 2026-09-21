pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    readonly property var graph:
        CodeWorkflowIr.graphFor(CodeWorkflowSession.subflowTargetId)
    readonly property var nodes: root.graph?.nodes ?? []
    readonly property var edges: root.graph?.edges ?? []

    readonly property real nodeWidth: 190
    readonly property real nodeHeight: 88
    readonly property real worldWidth: root.graphExtent("x", 1050)
    readonly property real worldHeight: root.graphExtent("y", 570)
    property string hoveredEdgeId: ""
    readonly property var edgeRouteCache: root.buildEdgeRouteCache()

    function graphExtent(axis: string, minimum: real): real {
        let extent = minimum
        for (const node of root.nodes) {
            const position = Number(node?.[axis] ?? 0)
            const size = axis === "x" ? root.nodeWidth : root.nodeHeight
            extent = Math.max(extent, position + size + 80)
        }
        return extent
    }

    function nodeById(nodeId: string): var {
        return root.nodes.find(node => node.id === nodeId) ?? null
    }

    function routeIntersectsNode(route, node, padding: real): bool {
        const left = Number(node?.x ?? 0) - padding
        const top = Number(node?.y ?? 0) - padding
        const right = Number(node?.x ?? 0) + root.nodeWidth + padding
        const bottom = Number(node?.y ?? 0) + root.nodeHeight + padding

        const routeLeft = Math.min(
            route.x0, route.x1, route.x2, route.x3)
        const routeTop = Math.min(
            route.y0, route.y1, route.y2, route.y3)
        const routeRight = Math.max(
            route.x0, route.x1, route.x2, route.x3)
        const routeBottom = Math.max(
            route.y0, route.y1, route.y2, route.y3)
        if (routeRight < left || routeLeft > right
                || routeBottom < top || routeTop > bottom)
            return false

        const steps = 32
        for (let step = 1; step < steps; ++step) {
            const t = step / steps
            const x = root.cubicCoordinate(
                route.x0, route.x1, route.x2, route.x3, t)
            const y = root.cubicCoordinate(
                route.y0, route.y1, route.y2, route.y3, t)
            if (x >= left && x <= right && y >= top && y <= bottom)
                return true
        }
        return false
    }

    function routeCollisionCount(route, edge): int {
        let collisions = 0
        for (const node of root.nodes) {
            const nodeId = String(node?.id ?? "")
            if (nodeId === String(edge?.from ?? "")
                    || nodeId === String(edge?.to ?? ""))
                continue
            if (root.routeIntersectsNode(route, node, 8))
                collisions += 1
        }
        return collisions
    }

    function detourRoute(route, offset: real): var {
        const candidate = {
            vertical: route.vertical,
            direction: route.direction,
            bend: route.bend,
            x0: route.x0, y0: route.y0,
            x1: route.x1, y1: route.y1,
            x2: route.x2, y2: route.y2,
            x3: route.x3, y3: route.y3
        }

        if (candidate.vertical) {
            candidate.x1 = candidate.x0 + offset
            candidate.y1 = candidate.y0
            candidate.x2 = candidate.x3 + offset
            candidate.y2 = candidate.y3
        } else {
            candidate.x1 = candidate.x0
            candidate.y1 = candidate.y0 + offset
            candidate.x2 = candidate.x3
            candidate.y2 = candidate.y3 + offset
        }
        return candidate
    }

    function edgeRoute(edge): var {
        const fromNode = root.nodeById(edge?.from ?? "")
        const toNode = root.nodeById(edge?.to ?? "")
        if (!fromNode || !toNode)
            return null

        const fromX = Number(fromNode.x ?? 0)
        const fromY = Number(fromNode.y ?? 0)
        const toX = Number(toNode.x ?? 0)
        const toY = Number(toNode.y ?? 0)
        const fromRight = fromX + root.nodeWidth
        const toRight = toX + root.nodeWidth
        const separatedRight = toX >= fromRight
        const separatedLeft = toRight <= fromX
        const vertical = !separatedRight && !separatedLeft

        let x0 = 0
        let y0 = 0
        let x1 = 0
        let y1 = 0
        let x2 = 0
        let y2 = 0
        let x3 = 0
        let y3 = 0
        let direction = 1
        let bend = 48

        if (vertical) {
            const downward = toY + root.nodeHeight / 2
                >= fromY + root.nodeHeight / 2
            direction = downward ? 1 : -1
            x0 = fromX + root.nodeWidth / 2
            y0 = fromY + (downward ? root.nodeHeight : 0)
            x3 = toX + root.nodeWidth / 2
            y3 = toY + (downward ? 0 : root.nodeHeight)
            bend = Math.max(48, Math.abs(y3 - y0) / 2)
            x1 = x0
            y1 = y0 + direction * bend
            x2 = x3
            y2 = y3 - direction * bend
        } else {
            const rightward = separatedRight
            direction = rightward ? 1 : -1
            x0 = fromX + (rightward ? root.nodeWidth : 0)
            y0 = fromY + root.nodeHeight / 2
            x3 = toX + (rightward ? 0 : root.nodeWidth)
            y3 = toY + root.nodeHeight / 2
            bend = Math.max(48, Math.abs(x3 - x0) / 2)
            x1 = x0 + direction * bend
            y1 = y0
            x2 = x3 - direction * bend
            y2 = y3
        }

        const route = {
            vertical: vertical,
            direction: direction,
            bend: bend,
            x0: x0, y0: y0,
            x1: x1, y1: y1,
            x2: x2, y2: y2,
            x3: x3, y3: y3
        }

        let bestRoute = route
        let bestCollisionCount = root.routeCollisionCount(route, edge)
        if (bestCollisionCount === 0)
            return route

        const detourOffsets = [
            120, -120, 180, -180, 240, -240,
            320, -320, 420, -420, 520, -520
        ]
        for (const offset of detourOffsets) {
            const candidate = root.detourRoute(route, offset)
            const collisionCount =
                root.routeCollisionCount(candidate, edge)
            if (collisionCount < bestCollisionCount) {
                bestRoute = candidate
                bestCollisionCount = collisionCount
            }
            if (collisionCount === 0)
                return candidate
        }
        return bestRoute
    }

    function buildEdgeRouteCache(): var {
        const cache = ({})
        const graph = root.graph
        for (const edge of (graph?.edges ?? [])) {
            const edgeId = String(edge?.id ?? "")
            if (edgeId.length > 0)
                cache[edgeId] = root.edgeRoute(edge)
        }
        return cache
    }

    function routeForEdge(edge): var {
        const edgeId = String(edge?.id ?? "")
        if (edgeId.length === 0)
            return root.edgeRoute(edge)
        const cached = root.edgeRouteCache[edgeId]
        return cached ?? root.edgeRoute(edge)
    }

    function graphBounds(): var {
        if (root.nodes.length === 0)
            return {
                x: 0, y: 0,
                width: root.worldWidth,
                height: root.worldHeight
            }

        let minX = Number.POSITIVE_INFINITY
        let minY = Number.POSITIVE_INFINITY
        let maxX = Number.NEGATIVE_INFINITY
        let maxY = Number.NEGATIVE_INFINITY

        for (const node of root.nodes) {
            const x = Number(node?.x ?? 0)
            const y = Number(node?.y ?? 0)
            minX = Math.min(minX, x)
            minY = Math.min(minY, y)
            maxX = Math.max(maxX, x + root.nodeWidth)
            maxY = Math.max(maxY, y + root.nodeHeight)
        }

        // Fit the same geometry that the renderer and hit-test use.
        for (const edge of root.edges) {
            const route = root.routeForEdge(edge)
            if (!route)
                continue
            minX = Math.min(
                minX, route.x0, route.x1, route.x2, route.x3)
            minY = Math.min(
                minY, route.y0, route.y1, route.y2, route.y3)
            maxX = Math.max(
                maxX, route.x0, route.x1, route.x2, route.x3)
            maxY = Math.max(
                maxY, route.y0, route.y1, route.y2, route.y3)
        }

        return {
            x: minX,
            y: minY,
            width: Math.max(1, maxX - minX),
            height: Math.max(1, maxY - minY)
        }
    }

    function pointSegmentDistance(
        px: real, py: real,
        ax: real, ay: real,
        bx: real, by: real
    ): real {
        const dx = bx - ax
        const dy = by - ay
        const lengthSquared = dx * dx + dy * dy
        if (lengthSquared <= 0.0001) {
            const sx = px - ax
            const sy = py - ay
            return Math.sqrt(sx * sx + sy * sy)
        }
        const t = Math.max(0, Math.min(1,
            ((px - ax) * dx + (py - ay) * dy) / lengthSquared))
        const qx = ax + t * dx
        const qy = ay + t * dy
        const sx = px - qx
        const sy = py - qy
        return Math.sqrt(sx * sx + sy * sy)
    }

    function cubicCoordinate(
        p0: real, p1: real, p2: real, p3: real, t: real
    ): real {
        const inv = 1 - t
        return inv * inv * inv * p0
            + 3 * inv * inv * t * p1
            + 3 * inv * t * t * p2
            + t * t * t * p3
    }

    function edgeDistance(edge, px: real, py: real): real {
        const route = root.routeForEdge(edge)
        if (!route)
            return 1e9

        let best = 1e9
        let previousX = route.x0
        let previousY = route.y0
        const steps = 20
        for (let step = 1; step <= steps; ++step) {
            const t = step / steps
            const nextX = root.cubicCoordinate(
                route.x0, route.x1, route.x2, route.x3, t)
            const nextY = root.cubicCoordinate(
                route.y0, route.y1, route.y2, route.y3, t)
            best = Math.min(best, root.pointSegmentDistance(
                px, py, previousX, previousY, nextX, nextY))
            previousX = nextX
            previousY = nextY
        }
        return best
    }

    function fitGraph(): void {
        if (root.width <= 0 || root.height <= 0)
            return
        const bounds = root.graphBounds()
        const margin = 28
        const availableWidth = Math.max(1, root.width - margin * 2)
        const availableHeight = Math.max(1, root.height - margin * 2)
        const nextZoom = Math.max(
            CodeWorkflowSession.minimumZoom,
            Math.min(
            1.4,
            availableWidth / Math.max(1, bounds.width),
            availableHeight / Math.max(1, bounds.height)))
        const nextX = (root.width - bounds.width * nextZoom) / 2
            - bounds.x * nextZoom
        const nextY = (root.height - bounds.height * nextZoom) / 2
            - bounds.y * nextZoom
        CodeWorkflowSession.setViewport(nextX, nextY, nextZoom)
    }

    function revealNode(nodeId: string): void {
        const node = root.nodeById(nodeId)
        if (!node || root.width <= 0 || root.height <= 0)
            return

        const zoom = Math.max(0.0001, CodeWorkflowSession.zoom)
        const margin = 34
        const left = CodeWorkflowSession.panX
            + Number(node.x ?? 0) * zoom
        const top = CodeWorkflowSession.panY
            + Number(node.y ?? 0) * zoom
        const right = left + root.nodeWidth * zoom
        const bottom = top + root.nodeHeight * zoom
        let nextX = CodeWorkflowSession.panX
        let nextY = CodeWorkflowSession.panY

        if (left < margin)
            nextX += margin - left
        else if (right > root.width - margin)
            nextX -= right - (root.width - margin)
        if (top < margin)
            nextY += margin - top
        else if (bottom > root.height - margin)
            nextY -= bottom - (root.height - margin)

        if (Math.abs(nextX - CodeWorkflowSession.panX) > 0.5
                || Math.abs(nextY - CodeWorkflowSession.panY) > 0.5)
            CodeWorkflowSession.setViewport(
                nextX, nextY, CodeWorkflowSession.zoom)
    }

    function nodeAtWorld(px: real, py: real): bool {
        return root.nodes.some(node => {
            const x = Number(node.x ?? 0)
            const y = Number(node.y ?? 0)
            return px >= x && px <= x + root.nodeWidth
                && py >= y && py <= y + root.nodeHeight
        })
    }

    function edgeAt(screenX: real, screenY: real): string {
        const zoom = Math.max(0.0001, CodeWorkflowSession.zoom)
        const worldX = (screenX - CodeWorkflowSession.panX) / zoom
        const worldY = (screenY - CodeWorkflowSession.panY) / zoom
        if (root.nodeAtWorld(worldX, worldY))
            return ""

        const tolerance = 8 / zoom
        let bestId = ""
        let bestDistance = tolerance
        for (const edge of root.edges) {
            const distance = root.edgeDistance(edge, worldX, worldY)
            if (distance <= bestDistance) {
                bestDistance = distance
                bestId = String(edge.id ?? "")
            }
        }
        return bestId
    }

    function accentForKind(kind: string): color {
        if (kind === "service")
            return Appearance.colors.colSecondary
        if (kind === "event" || kind === "action")
            return Appearance.colors.colTertiary
        if (kind === "lifecycle")
            return Appearance.colors.colPrimary
        if (kind === "binding")
            return Appearance.colors.colPrimary
        return Appearance.colors.colOnLayer1
    }

    function edgeColor(kind: string): color {
        if (kind === "event")
            return Appearance.colors.colTertiary
        if (kind === "action")
            return Appearance.colors.colSecondary
        if (kind === "data" || kind === "lifecycle")
            return Appearance.colors.colPrimary
        return Appearance.colors.colOutlineVariant
    }

    function edgeInk(kind: string, emphasized: bool): color {
        const base = root.edgeColor(kind)
        const readable = ColorUtils.readableAccentInk(
            base,
            Appearance.colors.colLayer0,
            emphasized ? 4.5 : 3.0,
            Appearance.colors.colOnLayer0)
        return readable
    }

    DragHandler {
        id: pan
        target: null
        acceptedButtons: Qt.MiddleButton
        property real baseX: 0
        property real baseY: 0

        onActiveChanged: {
            if (active) {
                baseX = CodeWorkflowSession.panX
                baseY = CodeWorkflowSession.panY
            }
        }
        onActiveTranslationChanged: {
            if (active)
                CodeWorkflowSession.setViewport(
                    baseX + activeTranslation.x,
                    baseY + activeTranslation.y,
                    CodeWorkflowSession.zoom)
        }
    }

    WheelHandler {
        target: null
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            const oldZoom = CodeWorkflowSession.zoom
            const delta = event.pixelDelta.y !== 0
                ? event.pixelDelta.y * 3
                : event.angleDelta.y
            const nextZoom = Math.max(
                CodeWorkflowSession.minimumZoom,
                Math.min(
                    CodeWorkflowSession.maximumZoom,
                    oldZoom * Math.pow(1.0015, delta)))
            const graphX = (event.x - CodeWorkflowSession.panX) / oldZoom
            const graphY = (event.y - CodeWorkflowSession.panY) / oldZoom
            CodeWorkflowSession.setViewport(
                event.x - graphX * nextZoom,
                event.y - graphY * nextZoom,
                nextZoom)
            event.accepted = true
        }
    }

    HoverHandler {
        id: edgeHover
        target: null

        onPointChanged: root.hoveredEdgeId = root.edgeAt(
            point.position.x, point.position.y)
        onHoveredChanged: {
            if (!hovered)
                root.hoveredEdgeId = ""
        }
    }

    TapHandler {
        id: edgeTap
        target: null
        acceptedButtons: Qt.LeftButton

        onTapped: (eventPoint, button) => {
            const edgeId = root.edgeAt(
                eventPoint.position.x, eventPoint.position.y)
            if (edgeId.length > 0)
                CodeWorkflowSession.selectEdge(edgeId)
        }
    }

    Connections {
        target: CodeWorkflowSession

        function onSubflowTargetIdChanged(): void {
            Qt.callLater(root.fitGraph)
        }

        function onSelectedNodeIdChanged(): void {
            Qt.callLater(() => root.revealNode(
                CodeWorkflowSession.selectedNodeId))
        }
    }

    PinchHandler {
        id: pinch
        target: null
        property real baseZoom: 1
        property point pivot: Qt.point(0, 0)

        onActiveChanged: {
            if (active) {
                baseZoom = CodeWorkflowSession.zoom
                pivot = Qt.point(
                    (centroid.position.x - CodeWorkflowSession.panX)
                        / CodeWorkflowSession.zoom,
                    (centroid.position.y - CodeWorkflowSession.panY)
                        / CodeWorkflowSession.zoom)
            }
        }

        function updateViewport(): void {
            if (!active)
                return
            const nextZoom = Math.max(
                CodeWorkflowSession.minimumZoom,
                Math.min(
                    CodeWorkflowSession.maximumZoom,
                    baseZoom * activeScale))
            CodeWorkflowSession.setViewport(
                centroid.position.x - pivot.x * nextZoom,
                centroid.position.y - pivot.y * nextZoom,
                nextZoom)
        }

        onActiveScaleChanged: updateViewport()
        onActiveTranslationChanged: updateViewport()
    }

    Rectangle {
        anchors.fill: parent
        color: Appearance.colors.colLayer0
        z: -2
    }

    Item {
        id: world
        width: root.worldWidth
        height: root.worldHeight
        x: CodeWorkflowSession.panX
        y: CodeWorkflowSession.panY
        scale: CodeWorkflowSession.zoom
        transformOrigin: Item.TopLeft

        Repeater {
            model: root.edges

            delegate: Shape {
                id: edgeShape
                required property var modelData

                readonly property var fromNode: root.nodeById(modelData.from)
                readonly property var toNode: root.nodeById(modelData.to)
                readonly property bool selectedEdge:
                    CodeWorkflowSession.selectedEdgeId === modelData.id
                readonly property bool hoveredEdge:
                    root.hoveredEdgeId === modelData.id
                readonly property bool highlighted:
                    selectedEdge
                    || hoveredEdge
                    || (CodeWorkflowSession.selectedEdgeId.length === 0
                        && CodeWorkflowSession.selectedSemanticAnchor.length === 0
                        && (CodeWorkflowSession.selectedNodeId
                                === modelData.from
                            || CodeWorkflowSession.selectedNodeId
                                === modelData.to))

                anchors.fill: parent
                preferredRendererType: Shape.GeometryRenderer
                asynchronous: false
                z: 0

                ShapePath {
                    id: edgePath
                    readonly property var route:
                        root.routeForEdge(edgeShape.modelData)

                    strokeColor: root.edgeInk(
                        edgeShape.modelData.kind,
                        edgeShape.highlighted)
                    strokeWidth: edgeShape.selectedEdge
                        ? 3.6
                        : edgeShape.highlighted ? 3.0 : 2.4
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin
                    fillColor: "transparent"
                    startX: route?.x0 ?? 0
                    startY: route?.y0 ?? 0

                    PathCubic {
                        x: edgePath.route?.x3 ?? 0
                        y: edgePath.route?.y3 ?? 0
                        control1X: edgePath.route?.x1 ?? 0
                        control1Y: edgePath.route?.y1 ?? 0
                        control2X: edgePath.route?.x2 ?? 0
                        control2Y: edgePath.route?.y2 ?? 0
                    }
                }

                ShapePath {
                    id: arrowPath
                    readonly property var route: edgePath.route
                    readonly property real tipX: route?.x3 ?? 0
                    readonly property real tipY: route?.y3 ?? 0
                    readonly property real tangentX:
                        tipX - Number(route?.x2 ?? tipX - 1)
                    readonly property real tangentY:
                        tipY - Number(route?.y2 ?? tipY)
                    readonly property real tangentLength:
                        Math.max(0.001, Math.sqrt(
                            tangentX * tangentX
                            + tangentY * tangentY))
                    readonly property real unitX: tangentX / tangentLength
                    readonly property real unitY: tangentY / tangentLength
                    readonly property real backX: tipX - unitX * 10
                    readonly property real backY: tipY - unitY * 10
                    readonly property color ink: root.edgeInk(
                        edgeShape.modelData.kind,
                        edgeShape.highlighted)

                    strokeColor: "transparent"
                    fillColor: ink
                    startX: tipX
                    startY: tipY

                    PathLine {
                        x: arrowPath.backX - arrowPath.unitY * 5
                        y: arrowPath.backY + arrowPath.unitX * 5
                    }
                    PathLine {
                        x: arrowPath.backX + arrowPath.unitY * 5
                        y: arrowPath.backY - arrowPath.unitX * 5
                    }
                    PathLine {
                        x: arrowPath.tipX
                        y: arrowPath.tipY
                    }
                }
            }
        }

        Repeater {
            model: root.edges

            delegate: Rectangle {
                id: edgeLabel
                required property var modelData

                readonly property var fromNode: root.nodeById(modelData.from)
                readonly property var toNode: root.nodeById(modelData.to)
                readonly property var route:
                    root.routeForEdge(modelData)
                readonly property real midX: route
                    ? root.cubicCoordinate(
                        route.x0, route.x1, route.x2, route.x3, 0.5)
                    : 0
                readonly property real midY: route
                    ? root.cubicCoordinate(
                        route.y0, route.y1, route.y2, route.y3, 0.5)
                    : 0
                readonly property real horizontalGap:
                    route && !route.vertical
                        ? Math.abs(route.x3 - route.x0)
                        : 150
                readonly property real labelWidthLimit:
                    route && !route.vertical
                        ? Math.max(24, horizontalGap - 12)
                        : 150
                readonly property bool hovered:
                    edgeLabelHover.hovered
                    || root.hoveredEdgeId === String(modelData.id ?? "")

                visible: fromNode !== null
                    && toNode !== null
                    && String(modelData.label ?? "").length > 0
                x: midX - width / 2
                y: midY - height / 2
                implicitWidth: Math.min(
                    150,
                    edgeLabel.labelWidthLimit,
                    edgeLabelText.implicitWidth + 12)
                implicitHeight: edgeLabelText.implicitHeight + 6
                radius: implicitHeight / 2
                color: Appearance.colors.colLayer0
                border.width: 1
                border.color: ColorUtils.applyAlpha(
                    root.edgeInk(modelData.kind, false), 0.72)
                z: 0.5

                HoverHandler {
                    id: edgeLabelHover
                    target: edgeLabel
                }

                StyledText {
                    id: edgeLabelText
                    anchors.fill: parent
                    anchors.leftMargin: 6
                    anchors.rightMargin: 6
                    verticalAlignment: Text.AlignVCenter
                    text: String(edgeLabel.modelData.label ?? "")
                    color: root.edgeInk(
                        edgeLabel.modelData.kind, true)
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                StyledToolTip {
                    text: String(edgeLabel.modelData.label ?? "")
                }
            }
        }

        Repeater {
            model: root.nodes

            delegate: Rectangle {
                id: node
                required property var modelData

                readonly property bool selected:
                    CodeWorkflowSession.selectedEdgeId.length === 0
                    && CodeWorkflowSession.selectedSemanticAnchor.length === 0
                    && CodeWorkflowSession.selectedNodeId === modelData.id
                readonly property color accent:
                    root.accentForKind(modelData.kind)
                readonly property color foreground: selected
                    ? Appearance.colors.colOnPrimaryContainer
                    : Appearance.colors.colOnLayer1
                readonly property color subtext: selected
                    ? ColorUtils.readableSubtext(
                        Appearance.colors.colOnPrimaryContainer,
                        Appearance.colors.colPrimaryContainer,
                        0.78)
                    : Appearance.colors.colSubtext
                readonly property color portInk:
                    ColorUtils.readableAccentInk(
                        accent,
                        Appearance.colors.colLayer0,
                        3.0,
                        Appearance.colors.colOnLayer0)

                x: Number(modelData.x ?? 0)
                y: Number(modelData.y ?? 0)
                width: root.nodeWidth
                height: root.nodeHeight
                radius: Appearance.rounding.normal
                color: selected
                    ? Appearance.colors.colPrimaryContainer
                    : Appearance.colors.colLayer1
                border.width: selected || activeFocus ? 2 : 1
                border.color: selected || activeFocus
                    ? accent
                    : Appearance.colors.colOutlineVariant
                z: 1
                activeFocusOnTab: true

                Accessible.role: Accessible.Button
                Accessible.name: modelData.title
                    + " · " + modelData.kind
                Accessible.description:
                    modelData.description ?? "Read-only workflow node"
                Accessible.focusable: true
                Accessible.onPressAction: {
                    CodeWorkflowSession.selectNode(node.modelData.id)
                }

                TapHandler {
                    onTapped: {
                        CodeWorkflowSession.selectNode(node.modelData.id)
                        node.forceActiveFocus()
                    }
                }

                Keys.onPressed: event => {
                    if (event.key !== Qt.Key_Return
                            && event.key !== Qt.Key_Enter
                            && event.key !== Qt.Key_Space) {
                        event.accepted = false
                        return
                    }

                    CodeWorkflowSession.selectNode(node.modelData.id)
                    event.accepted = true
                }

                ColumnLayout {
                    id: nodeContent
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 3
                    clip: true

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Rectangle {
                            implicitWidth: kindLabel.implicitWidth + 10
                            implicitHeight: kindLabel.implicitHeight + 4
                            radius: implicitHeight / 2
                            color: Appearance.colors.colLayer2

                            StyledText {
                                id: kindLabel
                                anchors.centerIn: parent
                                text: String(node.modelData.kind ?? "node").toUpperCase()
                                color: ColorUtils.readableAccentInk(
                                    node.accent,
                                    Appearance.colors.colLayer2,
                                    4.5,
                                    Appearance.colors.colOnLayer1)
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                font.weight: Font.DemiBold
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: node.modelData.title ?? node.modelData.id
                            color: node.foreground
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            visible:
                                (node.modelData.subflowTargetId ?? "").length > 0
                                && node.modelData.subflowTargetId
                                    !== CodeWorkflowSession.subflowTargetId
                            implicitWidth: 25
                            implicitHeight: 25
                            radius: implicitHeight / 2
                            color: Appearance.colors.colLayer2
                            border.width: subflowAction.activeFocus ? 1 : 0
                            border.color: node.accent

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "arrow_outward"
                                iconSize: Appearance.font.pixelSize.small
                                color: node.portInk
                            }

                            MouseArea {
                                id: subflowAction
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                activeFocusOnTab: parent.visible
                                Accessible.role: Accessible.Button
                                Accessible.name: "Open "
                                    + String(node.modelData.title ?? "node")
                                    + " subflow"
                                Accessible.focusable: parent.visible
                                Accessible.onPressAction:
                                    CodeWorkflowSession.openSubflow(
                                        node.modelData.subflowTargetId)

                                onClicked: mouse => {
                                    mouse.accepted = true
                                    CodeWorkflowSession.openSubflow(
                                        node.modelData.subflowTargetId)
                                }

                                Keys.onPressed: event => {
                                    if (event.key !== Qt.Key_Return
                                            && event.key !== Qt.Key_Enter
                                            && event.key !== Qt.Key_Space) {
                                        event.accepted = false
                                        return
                                    }
                                    CodeWorkflowSession.openSubflow(
                                        node.modelData.subflowTargetId)
                                    event.accepted = true
                                }
                            }
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        Layout.maximumWidth: node.width - 20
                        text: node.modelData.description ?? ""
                        color: node.subtext
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        Layout.maximumWidth: node.width - 20
                        text: node.modelData.sourceNeedle ?? ""
                        color: node.subtext
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        elide: Text.ElideMiddle
                    }
                }

                Rectangle {
                    x: -4
                    anchors.verticalCenter: parent.verticalCenter
                    width: 8
                    height: 8
                    radius: 4
                    color: node.portInk
                }

                Rectangle {
                    x: parent.width - 4
                    anchors.verticalCenter: parent.verticalCenter
                    width: 8
                    height: 8
                    radius: 4
                    color: node.portInk
                }
            }
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 10
        implicitWidth: hint.implicitWidth + 16
        implicitHeight: hint.implicitHeight + 8
        radius: Appearance.rounding.small
        color: Appearance.colors.colLayer2

        StyledText {
            id: hint
            anchors.centerIn: parent
            text: (root.graph?.title ?? "Workflow")
                + " · " + root.nodes.length + " nodes · "
                + Math.round(CodeWorkflowSession.zoom * 100) + "%"
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.smallest
        }
    }
}
