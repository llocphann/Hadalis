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
        const fromNode = root.nodeById(edge?.from ?? "")
        const toNode = root.nodeById(edge?.to ?? "")
        if (!fromNode || !toNode)
            return 1e9

        const x0 = Number(fromNode.x ?? 0) + root.nodeWidth
        const y0 = Number(fromNode.y ?? 0) + root.nodeHeight / 2
        const x3 = Number(toNode.x ?? 0)
        const y3 = Number(toNode.y ?? 0) + root.nodeHeight / 2
        const bend = Math.max(48, Math.abs(
            Number(toNode.x ?? 0) - Number(fromNode.x ?? 0)) / 2)
        const x1 = x0 + bend
        const y1 = y0
        const x2 = x3 - bend
        const y2 = y3

        let best = 1e9
        let previousX = x0
        let previousY = y0
        const steps = 20
        for (let step = 1; step <= steps; ++step) {
            const t = step / steps
            const nextX = root.cubicCoordinate(x0, x1, x2, x3, t)
            const nextY = root.cubicCoordinate(y0, y1, y2, y3, t)
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
        const margin = 28
        const availableWidth = Math.max(1, root.width - margin * 2)
        const availableHeight = Math.max(1, root.height - margin * 2)
        const nextZoom = Math.max(0.35, Math.min(
            1.4,
            availableWidth / Math.max(1, root.worldWidth),
            availableHeight / Math.max(1, root.worldHeight)))
        const nextX = (root.width - root.worldWidth * nextZoom) / 2
        const nextY = (root.height - root.worldHeight * nextZoom) / 2
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
            const nextZoom = Math.max(0.35, Math.min(2.5,
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
            const nextZoom = Math.max(0.35,
                Math.min(2.5, baseZoom * activeScale))
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
                    || (CodeWorkflowSession.selectedSemanticAnchor.length === 0
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
                    readonly property real startNodeX:
                        edgeShape.fromNode?.x ?? 0
                    readonly property real startNodeY:
                        edgeShape.fromNode?.y ?? 0
                    readonly property real endNodeX:
                        edgeShape.toNode?.x ?? 0
                    readonly property real endNodeY:
                        edgeShape.toNode?.y ?? 0
                    readonly property real bend:
                        Math.max(48,
                            Math.abs(endNodeX - startNodeX) / 2)

                    strokeColor: root.edgeInk(
                        edgeShape.modelData.kind,
                        edgeShape.highlighted)
                    strokeWidth: edgeShape.selectedEdge
                        ? 3.6
                        : edgeShape.highlighted ? 3.0 : 2.4
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin
                    fillColor: "transparent"
                    startX: startNodeX + root.nodeWidth
                    startY: startNodeY + root.nodeHeight / 2

                    PathCubic {
                        x: edgePath.endNodeX
                        y: edgePath.endNodeY + root.nodeHeight / 2
                        control1X: edgePath.startNodeX
                            + root.nodeWidth + edgePath.bend
                        control1Y: edgePath.startNodeY
                            + root.nodeHeight / 2
                        control2X: edgePath.endNodeX - edgePath.bend
                        control2Y: edgePath.endNodeY
                            + root.nodeHeight / 2
                    }
                }

                ShapePath {
                    id: arrowPath
                    readonly property real tipX:
                        Number(edgeShape.toNode?.x ?? 0)
                    readonly property real tipY:
                        Number(edgeShape.toNode?.y ?? 0)
                            + root.nodeHeight / 2
                    readonly property color ink: root.edgeInk(
                        edgeShape.modelData.kind,
                        edgeShape.highlighted)

                    strokeColor: "transparent"
                    fillColor: ink
                    startX: tipX
                    startY: tipY

                    PathLine {
                        x: arrowPath.tipX - 10
                        y: arrowPath.tipY - 5
                    }
                    PathLine {
                        x: arrowPath.tipX - 10
                        y: arrowPath.tipY + 5
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
                readonly property real startX:
                    Number(fromNode?.x ?? 0) + root.nodeWidth
                readonly property real startY:
                    Number(fromNode?.y ?? 0) + root.nodeHeight / 2
                readonly property real endX: Number(toNode?.x ?? 0)
                readonly property real endY:
                    Number(toNode?.y ?? 0) + root.nodeHeight / 2
                readonly property real bend:
                    Math.max(48, Math.abs(endX - startX) / 2)
                readonly property real midX: root.cubicCoordinate(
                    startX, startX + bend, endX - bend, endX, 0.5)
                readonly property real midY: root.cubicCoordinate(
                    startY, startY, endY, endY, 0.5)

                visible: fromNode !== null
                    && toNode !== null
                    && String(modelData.label ?? "").length > 0
                x: midX - width / 2
                y: midY - height / 2
                implicitWidth: Math.min(150,
                    edgeLabelText.implicitWidth + 12)
                implicitHeight: edgeLabelText.implicitHeight + 6
                radius: implicitHeight / 2
                color: Appearance.colors.colLayer0
                border.width: 1
                border.color: ColorUtils.applyAlpha(
                    root.edgeInk(modelData.kind, false), 0.72)
                z: 0.5

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
            }
        }

        Repeater {
            model: root.nodes

            delegate: Rectangle {
                id: node
                required property var modelData

                readonly property bool selected:
                    CodeWorkflowSession.selectedSemanticAnchor.length === 0
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
                border.width: selected ? 2 : 1
                border.color: selected
                    ? accent
                    : Appearance.colors.colOutlineVariant
                z: 1
                activeFocusOnTab: true

                Accessible.role: Accessible.Button
                Accessible.name: modelData.title
                    + " · " + modelData.kind
                Accessible.description:
                    modelData.description ?? "Read-only workflow node"

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

                    if ((node.modelData.subflowTargetId ?? "").length > 0
                            && node.modelData.subflowTargetId
                                !== CodeWorkflowSession.subflowTargetId)
                        CodeWorkflowSession.openSubflow(
                            node.modelData.subflowTargetId)
                    else
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

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "arrow_outward"
                                iconSize: Appearance.font.pixelSize.small
                                color: node.portInk
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: mouse => {
                                    mouse.accepted = true
                                    CodeWorkflowSession.openSubflow(
                                        node.modelData.subflowTargetId)
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
