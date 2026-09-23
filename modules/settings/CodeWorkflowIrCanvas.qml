pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

Item {
    id: root
    // The canvas itself is the hard viewport boundary. The transformed graph
    // may pan beyond it, but nodes, routes, labels and graph-local effects must
    // never paint into the toolbar or adjacent SplitView panes.
    clip: true

    // Text inside `world` is transformed by graph zoom. Native glyph
    // rasterization becomes visibly thin/hollow at fractional zoom levels,
    // while the Qt renderer remains stable under scene transforms.
    component GraphText: StyledText {
        renderType: Text.QtRendering
    }

    property bool showInternals: false
    // The Settings host may keep this canvas instantiated while another page
    // is current. Keep graph/session listeners dormant until Workflow owns input.
    property bool workflowActive: true
    // A pending/cached Settings page must not build the unified runtime graph.
    // Loader transitions can instantiate Workflow before it owns the page; an
    // empty presentation here keeps runtime/session state intact while avoiding
    // thousands of route/delegate bindings until the page is actually current.
    //
    // Keep the graph imperative rather than binding it directly to
    // CodeWorkflowRuntime.activeCatalog. Standalone Settings polls runtime IPC
    // periodically and receives a fresh descriptor array even when its
    // structural contents are unchanged. Rebuilding this graph on every poll
    // destroys/recreates all node, edge, label and route delegates.
    property var graph: null
    property string runtimeCatalogSignature: ""
    readonly property var groups: root.graph?.groups ?? []

    function catalogSignature(): string {
        const rows = []
        for (const descriptor of CodeWorkflowRuntime.activeCatalog) {
            rows.push([
                String(descriptor?.targetId ?? ""),
                String(descriptor?.label ?? ""),
                String(descriptor?.family ?? ""),
                String(descriptor?.kind ?? ""),
                descriptor?.internal === true ? "1" : "0",
                String(descriptor?.lifecycle ?? ""),
                String(descriptor?.state ?? ""),
                String(descriptor?.sourcePath ?? "")
            ].join("\u001f"))
        }
        rows.sort()
        return rows.join("\u001e")
    }

    function refreshGraph(force: bool): void {
        if (!root.workflowActive) {
            graphRefreshTimer.stop()
            return
        }
        const signature = root.catalogSignature()
        if (!force && root.graph !== null
                && signature === root.runtimeCatalogSignature)
            return
        root.runtimeCatalogSignature = signature
        root.graph = CodeWorkflowIr.unifiedGraphFor(root.showInternals)
    }

    Timer {
        id: graphRefreshTimer
        // A cached Workflow page keeps its graph ready for an instant revisit.
        // Initial construction or a hidden-time runtime change is reconciled
        // after the Settings slide finishes so graph delegate creation cannot
        // steal frames from the transition.
        interval: Math.max(
            32, Appearance.animation.elementMoveFast.duration + 24)
        repeat: false
        onTriggered: root.refreshGraph(false)
    }
    property bool initialFitDone: false
    readonly property bool inventoryReady: CodeWorkflowIr.ready
        && (CodeWorkflowRuntime.hasLocalDeclarations
            || CodeWorkflowRuntime.remoteSnapshot !== null)
    function fitInitialGraph(): void {
        if (!root.workflowActive)
            return
        // Local Loader declarations register incrementally. Debounce their
        // arrivals instead of fitting the first partial inventory. An IPC
        // error is not a complete inventory; wait for a real snapshot.
        // A restored or manually changed viewport takes precedence over Fit.
        if (root.initialFitDone)
            return
        if (CodeWorkflowSession.viewportInitialized) {
            initialFitTimer.stop()
            root.initialFitDone = true
            return
        }
        if (!root.inventoryReady || root.width < 240 || root.height < 160
                || root.nodes.length === 0)
            return
        initialFitTimer.restart()
    }
    Timer {
        id: runtimePulseTimer
        interval: 1100
        repeat: false
        onTriggered: {
            root.runtimePulseTargetId = ""
            root.runtimePulseKind = ""
        }
    }

    Timer {
        id: initialFitTimer
        interval: 450
        repeat: false
        onTriggered: {
            if (!root.workflowActive)
                return
            if (root.initialFitDone
                    || CodeWorkflowSession.viewportInitialized) {
                root.initialFitDone = true
                return
            }
            if (!root.inventoryReady || root.width < 240
                    || root.height < 160 || root.nodes.length === 0)
                return
            root.initialFitDone = true
            root.fitGraph()
        }
    }
    onInventoryReadyChanged: root.fitInitialGraph()
    onWidthChanged: root.fitInitialGraph()
    onHeightChanged: root.fitInitialGraph()
    onGraphChanged: {
        root.marqueeActive = false
        root.marqueeBaseNodeIds = []
        root.clearMarqueeReasoningSnapshot()
        root.clearReasoningSelection()
        root.rebuildStructureCache()
        if (root.workflowActive)
            root.scheduleEdgeRouteCacheRebuild()
        root.fitInitialGraph()
    }
    readonly property var nodes: root.graph?.nodes ?? []
    readonly property var edges: root.graph?.edges ?? []
    // Hot routing and hit-test paths resolve node IDs repeatedly. Index graph
    // structure once per graph replacement instead of linearly scanning the
    // node array for every edge candidate.
    property var nodeIndexCache: ({})
    property var outgoingEdgesCache: ({})
    property var nodeLayoutOffsetCache: ({})

    function rebuildNodeLayoutOffsetCache(): void {
        const cache = ({})
        for (const node of root.nodes) {
            const nodeId = String(node?.id ?? "")
            if (nodeId.length === 0)
                continue
            const offset = CodeWorkflowSession.nodeLayoutOffset(
                String(node?.graphId ?? CodeWorkflowSession.subflowTargetId),
                nodeId)
            const x = Number(offset?.x ?? 0)
            const y = Number(offset?.y ?? 0)
            if (Math.abs(x) >= 0.001 || Math.abs(y) >= 0.001)
                cache[nodeId] = { x: x, y: y }
        }
        root.nodeLayoutOffsetCache = cache
    }

    function rebuildStructureCache(): void {
        const nodeIndex = ({})
        for (const node of root.nodes) {
            const id = String(node?.id ?? "")
            if (id.length > 0)
                nodeIndex[id] = node
        }

        const outgoing = ({})
        for (const edge of root.edges) {
            const fromId = String(edge?.from ?? "")
            if (fromId.length === 0)
                continue
            if (!outgoing[fromId])
                outgoing[fromId] = []
            outgoing[fromId].push(edge)
        }
        root.nodeIndexCache = nodeIndex
        root.outgoingEdgesCache = outgoing
        root.rebuildNodeLayoutOffsetCache()
    }

    readonly property real nodeWidth: 190
    readonly property real nodeHeight: 88
    // Extents/bounds depend on graph structure and committed node layout, not
    // viewport pan/zoom. Keep them imperative so wheel/pinch and node-drag
    // frames do not repeatedly walk every node, group and routed edge.
    property real cachedWorldWidth: 1050
    property real cachedWorldHeight: 570
    property var graphBoundsCache: ({
        x: 0, y: 0, width: 1050, height: 570
    })
    readonly property real worldWidth: root.cachedWorldWidth
    readonly property real worldHeight: root.cachedWorldHeight
    property string hoveredEdgeId: ""
    property string hoveredEdgeLabelId: ""
    // Wire stroke/arrow metrics are screen-space compensation values. Updating
    // them on every touchpad/wheel sample invalidates every ShapePath even
    // though the world transform already gives immediate visual zoom. Sample
    // the compensation at a bounded cadence and settle to the final zoom.
    property real wireMetricZoom: 1
    property real edgeLabelHoverX: 0
    property real edgeLabelHoverY: 0
    property var activeNodeDragHandler: null
    property string activeNodeDragId: ""
    property real activeNodeDragSceneX: 0
    property real activeNodeDragSceneY: 0
    property real activeNodeDragOffsetX: 0
    property real activeNodeDragOffsetY: 0
    property bool dragRoutesDirty: false
    // Full smart routing is committed only when layout state changes. During a
    // pointer drag we keep this cache stable and recompute only attached edges.
    property var edgeRouteCache: ({})
    property var dragEdgeRouteCache: ({})
    // Graph reasoning selection is presentation-only. It never changes the
    // primary Inspector selection or mutation authority.
    property string reasoningMode: ""
    property var reasoningNodeIds: []
    property var reasoningEdgeIds: []
    readonly property bool hasReasoningSelection:
        root.reasoningNodeIds.length > 0
    readonly property bool minimapVisible: minimap.visible
    readonly property bool minimapNeeded: {
        if (!CodeWorkflowSession.minimapEnabled
                || root.width < 520 || root.height < 320
                || root.nodes.length === 0)
            return false
        const bounds = root.graphBoundsCache
        const zoom = Math.max(
            CodeWorkflowSession.minimumZoom, CodeWorkflowSession.zoom)
        return bounds.width * zoom > root.width - 96
            || bounds.height * zoom > root.height - 96
    }
    // Shift-drag on empty canvas starts a marquee selection. Holding Ctrl
    // while starting the marquee adds to the existing manual selection.
    property bool marqueeActive: false
    property real marqueeStartX: 0
    property real marqueeStartY: 0
    property real marqueeCurrentX: 0
    property real marqueeCurrentY: 0
    property var marqueeBaseNodeIds: []
    // Runtime activity here is lifecycle-only evidence from the existing
    // registry event buffer. It must never imply binding execution.
    property string runtimePulseTargetId: ""
    property string runtimePulseKind: ""
    property string runtimePulseSignature: ""
    // Marquee updates reasoning live for visual feedback. Preserve the exact
    // pre-gesture presentation state so cancellation cannot leave a partial set.
    property string marqueeRestoreReasoningMode: ""
    property var marqueeRestoreNodeIds: []
    property var marqueeRestoreEdgeIds: []

    function runtimeEventTargetId(event): string {
        const explicitTargetId = String(event?.targetId ?? "")
        if (explicitTargetId.length > 0)
            return explicitTargetId
        const identity = String(event?.instanceId ?? "")
        const split = identity.lastIndexOf("@")
        return split > 0 ? identity.slice(0, split) : identity
    }

    function consumeRuntimeLifecycleEvent(): void {
        if (!root.workflowActive)
            return
        const snapshot = CodeWorkflowRuntime.snapshot()
        const events = snapshot?.events ?? []
        if (events.length === 0)
            return
        const event = events[events.length - 1]
        const targetId = root.runtimeEventTargetId(event)
        const signature = String(event?.kind ?? "")
            + "|" + targetId
            + "|" + String(event?.instanceId ?? "")
            + "|" + String(event?.token ?? "")
            + "|" + String(event?.atMs ?? "")
        if (signature === root.runtimePulseSignature)
            return
        root.runtimePulseSignature = signature

        const atMs = Number(event?.atMs ?? 0)
        if (!root.visible || targetId.length === 0
                || (Number.isFinite(atMs) && atMs > 0
                    && Date.now() - atMs > 2500)) {
            root.runtimePulseTargetId = ""
            root.runtimePulseKind = ""
            return
        }

        root.runtimePulseTargetId = targetId
        root.runtimePulseKind = String(event?.kind ?? "runtime")
        runtimePulseTimer.restart()
    }

    function nodeMatchesRuntimeTarget(node, targetId: string): bool {
        const expected = String(targetId ?? "")
        if (expected.length === 0)
            return false
        return String(node?.runtimeTargetId ?? "") === expected
            || String(node?.targetId ?? "") === expected
            || String(node?.id ?? "") === expected
    }

    function nodeLayoutOffset(node): var {
        return root.nodeLayoutOffsetCache[String(node?.id ?? "")] ?? null
    }

    function nodeX(node): real {
        const nodeId = String(node?.id ?? "")
        const offsetX = nodeId.length > 0 && nodeId === root.activeNodeDragId
            ? root.activeNodeDragOffsetX
            : Number(root.nodeLayoutOffsetCache[nodeId]?.x ?? 0)
        return Number(node?.x ?? 0) + offsetX
    }

    function nodeY(node): real {
        const nodeId = String(node?.id ?? "")
        const offsetY = nodeId.length > 0 && nodeId === root.activeNodeDragId
            ? root.activeNodeDragOffsetY
            : Number(root.nodeLayoutOffsetCache[nodeId]?.y ?? 0)
        return Number(node?.y ?? 0) + offsetY
    }

    function graphExtent(axis: string, minimum: real): real {
        let extent = minimum
        for (const node of root.nodes) {
            const position = axis === "x"
                ? root.nodeX(node) : root.nodeY(node)
            const size = axis === "x" ? root.nodeWidth : root.nodeHeight
            extent = Math.max(extent, position + size + 80)
        }
        for (const group of root.groups)
            extent = Math.max(extent,
                Number(group[axis] ?? 0)
                    + Number(axis === "x" ? group.width : group.height)
                    + 40)
        return extent
    }

    function nodeById(nodeId: string): var {
        const node = root.nodeIndexCache[String(nodeId ?? "")] ?? null
        if (!node)
            return null
        const resolved = Object.assign({}, node)
        resolved.x = root.nodeX(node)
        resolved.y = root.nodeY(node)
        return resolved
    }

    function clearReasoningSelection(): void {
        root.reasoningMode = ""
        root.reasoningNodeIds = []
        root.reasoningEdgeIds = []
    }

    function snapshotMarqueeReasoning(): void {
        root.marqueeRestoreReasoningMode = root.reasoningMode
        root.marqueeRestoreNodeIds = root.reasoningNodeIds.slice()
        root.marqueeRestoreEdgeIds = root.reasoningEdgeIds.slice()
    }

    function clearMarqueeReasoningSnapshot(): void {
        root.marqueeRestoreReasoningMode = ""
        root.marqueeRestoreNodeIds = []
        root.marqueeRestoreEdgeIds = []
    }

    function restoreMarqueeReasoningSnapshot(): void {
        root.reasoningMode = root.marqueeRestoreReasoningMode
        root.reasoningNodeIds = root.marqueeRestoreNodeIds.slice()
        root.reasoningEdgeIds = root.marqueeRestoreEdgeIds.slice()
        root.clearMarqueeReasoningSnapshot()
    }

    function setManualReasoningSelection(nodeIds): void {
        const seen = ({})
        const sanitized = []
        for (const rawId of nodeIds ?? []) {
            const nodeId = String(rawId ?? "")
            if (nodeId.length === 0 || seen[nodeId] || !root.nodeById(nodeId))
                continue
            seen[nodeId] = true
            sanitized.push(nodeId)
        }
        if (sanitized.length === 0) {
            root.clearReasoningSelection()
            return
        }

        const edgeIds = []
        for (const edge of root.edges) {
            const fromId = String(edge?.from ?? "")
            const toId = String(edge?.to ?? "")
            if (seen[fromId] && seen[toId])
                edgeIds.push(String(edge?.id ?? ""))
        }
        root.reasoningMode = "manual"
        root.reasoningNodeIds = sanitized
        root.reasoningEdgeIds = edgeIds
    }

    function toggleManualNodeSelection(node): void {
        const nodeId = String(node?.id ?? "")
        if (nodeId.length === 0 || !root.nodeById(nodeId))
            return

        let selected = root.reasoningMode === "manual"
            ? root.reasoningNodeIds.slice() : []
        const primaryId = String(CodeWorkflowSession.selectedNodeId ?? "")
        if (selected.length === 0 && primaryId.length > 0
                && root.nodeById(primaryId))
            selected.push(primaryId)

        const existingIndex = selected.indexOf(nodeId)
        if (existingIndex >= 0) {
            selected.splice(existingIndex, 1)
            if (selected.length > 0 && primaryId === nodeId) {
                const fallbackId = selected[selected.length - 1]
                const fallbackNode = root.nodes.find(candidate =>
                    String(candidate?.id ?? "") === fallbackId) ?? null
                if (fallbackNode)
                    CodeWorkflowSession.selectUnifiedNode(fallbackNode)
            }
            // An empty manual set clears only reasoning emphasis. The primary
            // Inspector selection remains intact and therefore retains the sole
            // mutation authority.
            root.setManualReasoningSelection(selected)
            return
        }

        selected.push(nodeId)
        CodeWorkflowSession.selectUnifiedNode(node)
        root.setManualReasoningSelection(selected)
    }

    function marqueeSelectionIds(): var {
        const left = Math.min(root.marqueeStartX, root.marqueeCurrentX)
        const right = Math.max(root.marqueeStartX, root.marqueeCurrentX)
        const top = Math.min(root.marqueeStartY, root.marqueeCurrentY)
        const bottom = Math.max(root.marqueeStartY, root.marqueeCurrentY)
        const zoom = Math.max(0.0001, CodeWorkflowSession.zoom)
        const worldLeft = (left - CodeWorkflowSession.panX) / zoom
        const worldRight = (right - CodeWorkflowSession.panX) / zoom
        const worldTop = (top - CodeWorkflowSession.panY) / zoom
        const worldBottom = (bottom - CodeWorkflowSession.panY) / zoom

        const selected = []
        for (const node of root.nodes) {
            const nodeLeft = root.nodeX(node)
            const nodeTop = root.nodeY(node)
            const nodeRight = nodeLeft + root.nodeWidth
            const nodeBottom = nodeTop + root.nodeHeight
            if (nodeRight >= worldLeft && nodeLeft <= worldRight
                    && nodeBottom >= worldTop && nodeTop <= worldBottom)
                selected.push(String(node?.id ?? ""))
        }
        return selected
    }

    function updateMarqueeSelection(): void {
        const combined = root.marqueeBaseNodeIds.slice()
        for (const nodeId of root.marqueeSelectionIds()) {
            if (!combined.includes(nodeId))
                combined.push(nodeId)
        }
        root.setManualReasoningSelection(combined)
    }

    function reasoningSelectionFor(mode: string): var {
        const nextMode = String(mode ?? "")
        if (!["upstream", "downstream", "connected"].includes(nextMode))
            return ({ nodes: [], edges: [] })

        const seeds = []
        const selectedEdge = root.edges.find(edge =>
            String(edge?.id ?? "") === CodeWorkflowSession.selectedEdgeId)
            ?? null
        if (selectedEdge) {
            seeds.push(String(selectedEdge.from ?? ""))
            seeds.push(String(selectedEdge.to ?? ""))
        } else {
            seeds.push(String(CodeWorkflowSession.selectedNodeId ?? ""))
        }

        const visited = ({})
        const traversedEdges = ({})
        const selectedEdgeId = String(selectedEdge?.id ?? "")
        if (selectedEdgeId.length > 0)
            traversedEdges[selectedEdgeId] = true

        const queue = []
        for (const seed of seeds) {
            if (seed.length === 0 || !root.nodeById(seed) || visited[seed])
                continue
            visited[seed] = true
            queue.push(seed)
        }

        while (queue.length > 0) {
            const current = queue.shift()
            for (const edge of root.edges) {
                const fromId = String(edge?.from ?? "")
                const toId = String(edge?.to ?? "")
                let neighbor = ""
                if (nextMode === "upstream" && toId === current)
                    neighbor = fromId
                else if (nextMode === "downstream" && fromId === current)
                    neighbor = toId
                else if (nextMode === "connected") {
                    if (fromId === current)
                        neighbor = toId
                    else if (toId === current)
                        neighbor = fromId
                }
                if (neighbor.length === 0 || !root.nodeById(neighbor))
                    continue

                // Reasoning wires must reflect the traversal itself. In
                // directional modes, do not highlight an opposite-direction
                // edge merely because both of its endpoints are reachable.
                const edgeId = String(edge?.id ?? "")
                if (edgeId.length > 0)
                    traversedEdges[edgeId] = true

                if (visited[neighbor])
                    continue
                visited[neighbor] = true
                queue.push(neighbor)
            }
        }

        return ({
            nodes: Object.keys(visited),
            edges: Object.keys(traversedEdges)
        })
    }

    function focusReasoning(mode: string): void {
        const nextMode = String(mode ?? "")
        if (root.reasoningMode === nextMode) {
            root.clearReasoningSelection()
            return
        }
        const selection = root.reasoningSelectionFor(nextMode)
        root.reasoningMode = nextMode
        root.reasoningNodeIds = selection.nodes
        root.reasoningEdgeIds = selection.edges
        Qt.callLater(root.fitSelection)
    }

    function rawNodeBounds(): var {
        if (root.nodes.length === 0)
            return { minX: 0, minY: 0, maxX: 0, maxY: 0 }

        let minX = Number.POSITIVE_INFINITY
        let minY = Number.POSITIVE_INFINITY
        let maxX = Number.NEGATIVE_INFINITY
        let maxY = Number.NEGATIVE_INFINITY
        for (const node of root.nodes) {
            const x = root.nodeX(node)
            const y = root.nodeY(node)
            minX = Math.min(minX, x)
            minY = Math.min(minY, y)
            maxX = Math.max(maxX, x + root.nodeWidth)
            maxY = Math.max(maxY, y + root.nodeHeight)
        }
        return { minX, minY, maxX, maxY }
    }

    function normalizeRoutePoints(points): var {
        const compact = []
        for (const point of points) {
            const next = {
                x: Number(point?.x ?? 0),
                y: Number(point?.y ?? 0)
            }
            const previous = compact[compact.length - 1]
            if (previous
                    && Math.abs(previous.x - next.x) < 0.001
                    && Math.abs(previous.y - next.y) < 0.001)
                continue
            compact.push(next)
        }

        let changed = true
        while (changed && compact.length > 2) {
            changed = false
            for (let index = 1; index < compact.length - 1; ++index) {
                const before = compact[index - 1]
                const point = compact[index]
                const after = compact[index + 1]
                const sameX = Math.abs(before.x - point.x) < 0.001
                    && Math.abs(point.x - after.x) < 0.001
                const sameY = Math.abs(before.y - point.y) < 0.001
                    && Math.abs(point.y - after.y) < 0.001
                if (sameX || sameY) {
                    compact.splice(index, 1)
                    changed = true
                    break
                }
            }
        }
        return compact
    }

    function pointToward(fromPoint, toPoint, distance: real): var {
        if (Math.abs(fromPoint.x - toPoint.x) < 0.001) {
            return {
                x: fromPoint.x,
                y: fromPoint.y
                    + Math.sign(toPoint.y - fromPoint.y) * distance
            }
        }
        return {
            x: fromPoint.x
                + Math.sign(toPoint.x - fromPoint.x) * distance,
            y: fromPoint.y
        }
    }

    function smoothStepSvg(points): string {
        if (!points || points.length < 2)
            return ""

        const radius = 14
        let path = "M " + points[0].x + " " + points[0].y
        for (let index = 1; index < points.length - 1; ++index) {
            const previous = points[index - 1]
            const point = points[index]
            const next = points[index + 1]
            const incoming = Math.abs(point.x - previous.x)
                + Math.abs(point.y - previous.y)
            const outgoing = Math.abs(next.x - point.x)
                + Math.abs(next.y - point.y)
            const corner = Math.min(radius, incoming / 2, outgoing / 2)
            if (corner < 0.5) {
                path += " L " + point.x + " " + point.y
                continue
            }
            const before = root.pointToward(point, previous, corner)
            const after = root.pointToward(point, next, corner)
            path += " L " + before.x + " " + before.y
                + " Q " + point.x + " " + point.y
                + " " + after.x + " " + after.y
        }
        const last = points[points.length - 1]
        path += " L " + last.x + " " + last.y
        return path
    }

    function routeFromPoints(points, vertical: bool, direction: real): var {
        const normalized = root.normalizeRoutePoints(points)
        if (normalized.length < 2)
            return null

        const first = normalized[0]
        const last = normalized[normalized.length - 1]
        let labelFrom = normalized[0]
        let labelTo = normalized[1]
        let foundTargetHorizontal = false
        for (let index = normalized.length - 1; index >= 1; --index) {
            const segmentFrom = normalized[index - 1]
            const segmentTo = normalized[index]
            const horizontal =
                Math.abs(segmentTo.y - segmentFrom.y) < 0.001
            if (!horizontal)
                continue
            labelFrom = segmentFrom
            labelTo = segmentTo
            foundTargetHorizontal = true
            break
        }

        if (!foundTargetHorizontal) {
            let bestSpan = -1
            for (let index = 1; index < normalized.length; ++index) {
                const segmentFrom = normalized[index - 1]
                const segmentTo = normalized[index]
                const span = Math.abs(segmentTo.x - segmentFrom.x)
                    + Math.abs(segmentTo.y - segmentFrom.y)
                if (span > bestSpan) {
                    bestSpan = span
                    labelFrom = segmentFrom
                    labelTo = segmentTo
                }
            }
        }
        return {
            points: normalized,
            vertical: vertical,
            direction: direction,
            x0: first.x,
            y0: first.y,
            x3: last.x,
            y3: last.y,
            labelX: (labelFrom.x + labelTo.x) / 2,
            labelY: (labelFrom.y + labelTo.y) / 2,
            labelSpan: Math.abs(labelTo.x - labelFrom.x)
                + Math.abs(labelTo.y - labelFrom.y),
            labelHorizontal:
                Math.abs(labelTo.y - labelFrom.y) < 0.001,
            svg: root.smoothStepSvg(normalized)
        }
    }

    function routeBounds(route): var {
        if (route?.bounds)
            return route.bounds
        if (!route?.points || route.points.length === 0)
            return { minX: 0, minY: 0, maxX: 0, maxY: 0 }

        let minX = Number.POSITIVE_INFINITY
        let minY = Number.POSITIVE_INFINITY
        let maxX = Number.NEGATIVE_INFINITY
        let maxY = Number.NEGATIVE_INFINITY
        for (const point of route.points) {
            minX = Math.min(minX, point.x)
            minY = Math.min(minY, point.y)
            maxX = Math.max(maxX, point.x)
            maxY = Math.max(maxY, point.y)
        }
        return { minX, minY, maxX, maxY }
    }

    function segmentIntersectsRect(
        fromPoint, toPoint,
        left: real, top: real, right: real, bottom: real
    ): bool {
        if (Math.abs(fromPoint.x - toPoint.x) < 0.001) {
            const x = fromPoint.x
            const minY = Math.min(fromPoint.y, toPoint.y)
            const maxY = Math.max(fromPoint.y, toPoint.y)
            return x >= left && x <= right
                && maxY >= top && minY <= bottom
        }
        if (Math.abs(fromPoint.y - toPoint.y) < 0.001) {
            const y = fromPoint.y
            const minX = Math.min(fromPoint.x, toPoint.x)
            const maxX = Math.max(fromPoint.x, toPoint.x)
            return y >= top && y <= bottom
                && maxX >= left && minX <= right
        }
        return false
    }

    function routeIntersectsNode(route, node, padding: real): bool {
        const nodeX = root.nodeX(node)
        const nodeY = root.nodeY(node)
        const left = nodeX - padding
        const top = nodeY - padding
        const right = nodeX + root.nodeWidth + padding
        const bottom = nodeY + root.nodeHeight + padding
        const points = route?.points ?? []
        for (let index = 1; index < points.length; ++index) {
            if (root.segmentIntersectsRect(
                    points[index - 1], points[index],
                    left, top, right, bottom))
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
            if (root.routeIntersectsNode(route, node, 10))
                collisions += 1
        }
        return collisions
    }

    function routeLength(route): real {
        const points = route?.points ?? []
        let length = 0
        for (let index = 1; index < points.length; ++index) {
            length += Math.abs(points[index].x - points[index - 1].x)
                + Math.abs(points[index].y - points[index - 1].y)
        }
        return length
    }

    function edgeLaneOffset(
        edge, vertical: bool, direction: real
    ): real {
        const fromId = String(edge?.from ?? "")
        const siblings = (root.outgoingEdgesCache[fromId] ?? []).slice()
        if (siblings.length <= 1)
            return 0

        const axis = vertical ? "x" : "y"
        siblings.sort((left, right) => {
            const leftNode = root.nodeById(left?.to ?? "")
            const rightNode = root.nodeById(right?.to ?? "")
            const leftPosition = Number(leftNode?.[axis] ?? 0)
            const rightPosition = Number(rightNode?.[axis] ?? 0)
            if (Math.abs(leftPosition - rightPosition) > 0.001)
                return leftPosition - rightPosition
            return String(left?.id ?? "").localeCompare(
                String(right?.id ?? ""))
        })

        const edgeId = String(edge?.id ?? "")
        const index = siblings.findIndex(candidate =>
            String(candidate?.id ?? "") === edgeId)
        if (index < 0)
            return 0

        const middle = (siblings.length - 1) / 2
        // Dense fan-out needs more screen-visible separation after Fit.
        // Keep small groups compact while spreading large lifecycle trees.
        const laneSpacing = siblings.length >= 8
            ? 12 : siblings.length >= 4 ? 10 : 8
        return Math.max(-64, Math.min(
            64, (middle - index) * laneSpacing * direction))
    }

    function segmentsCross(firstA, firstB, secondA, secondB): bool {
        const firstVertical =
            Math.abs(firstA.x - firstB.x) < 0.001
        const secondVertical =
            Math.abs(secondA.x - secondB.x) < 0.001
        if (firstVertical === secondVertical)
            return false

        const verticalA = firstVertical ? firstA : secondA
        const verticalB = firstVertical ? firstB : secondB
        const horizontalA = firstVertical ? secondA : firstA
        const horizontalB = firstVertical ? secondB : firstB
        const x = verticalA.x
        const y = horizontalA.y
        const epsilon = 0.001
        return x > Math.min(horizontalA.x, horizontalB.x) + epsilon
            && x < Math.max(horizontalA.x, horizontalB.x) - epsilon
            && y > Math.min(verticalA.y, verticalB.y) + epsilon
            && y < Math.max(verticalA.y, verticalB.y) - epsilon
    }

    function routeCrossingCount(route, occupiedRoutes): int {
        const points = route?.points ?? []
        let crossings = 0
        for (const occupied of (occupiedRoutes ?? [])) {
            const otherPoints = occupied?.points ?? []
            for (let first = 1; first < points.length; ++first) {
                for (let second = 1;
                        second < otherPoints.length; ++second) {
                    if (root.segmentsCross(
                            points[first - 1], points[first],
                            otherPoints[second - 1],
                            otherPoints[second]))
                        crossings += 1
                }
            }
        }
        return crossings
    }

    function segmentOverlapLength(firstA, firstB, secondA, secondB): real {
        const firstVertical =
            Math.abs(firstA.x - firstB.x) < 0.001
        const secondVertical =
            Math.abs(secondA.x - secondB.x) < 0.001
        if (firstVertical !== secondVertical)
            return 0

        if (firstVertical) {
            if (Math.abs(firstA.x - secondA.x) >= 0.001)
                return 0
            const start = Math.max(
                Math.min(firstA.y, firstB.y),
                Math.min(secondA.y, secondB.y))
            const end = Math.min(
                Math.max(firstA.y, firstB.y),
                Math.max(secondA.y, secondB.y))
            return Math.max(0, end - start)
        }

        if (Math.abs(firstA.y - secondA.y) >= 0.001)
            return 0
        const start = Math.max(
            Math.min(firstA.x, firstB.x),
            Math.min(secondA.x, secondB.x))
        const end = Math.min(
            Math.max(firstA.x, firstB.x),
            Math.max(secondA.x, secondB.x))
        return Math.max(0, end - start)
    }

    function routeOverlapLength(route, edge, occupiedRoutes): real {
        const points = route?.points ?? []
        let overlap = 0
        for (const occupied of (occupiedRoutes ?? [])) {
            const otherPoints = occupied?.points ?? []
            const currentFrom = String(edge?.from ?? "")
            const currentTo = String(edge?.to ?? "")
            const occupiedFrom = String(occupied?.fromId ?? "")
            const occupiedTo = String(occupied?.toId ?? "")
            for (let first = 1; first < points.length; ++first) {
                for (let second = 1;
                        second < otherPoints.length; ++second) {
                    const length = root.segmentOverlapLength(
                        points[first - 1], points[first],
                        otherPoints[second - 1], otherPoints[second])
                    if (length <= 0)
                        continue

                    // Node-level IR has one abstract port per side rather than
                    // Blender/Blueprint-style semantic sockets. Segments that
                    // overlap only while touching the same endpoint are
                    // therefore intentional bundling, regardless of whether
                    // one edge enters and the other leaves that node.
                    const currentAtSource = first === 1
                    const currentAtTarget =
                        first === points.length - 1
                    const occupiedAtSource = second === 1
                    const occupiedAtTarget =
                        second === otherPoints.length - 1
                    const sharedEndpoint =
                        (currentAtSource && occupiedAtSource
                            && currentFrom === occupiedFrom)
                        || (currentAtSource && occupiedAtTarget
                            && currentFrom === occupiedTo)
                        || (currentAtTarget && occupiedAtSource
                            && currentTo === occupiedFrom)
                        || (currentAtTarget && occupiedAtTarget
                            && currentTo === occupiedTo)
                    overlap += sharedEndpoint ? 0 : length
                }
            }
        }
        return overlap
    }

    function routeScore(route, edge, occupiedRoutes): real {
        const collisions = root.routeCollisionCount(route, edge)
        const crossings =
            root.routeCrossingCount(route, occupiedRoutes)
        const overlap =
            root.routeOverlapLength(route, edge, occupiedRoutes)
        const bends = Math.max(0, (route?.points?.length ?? 2) - 2)
        return collisions * 1000000000
            + crossings * 1000000
            + overlap * 1000
            + root.routeLength(route)
            + bends * 18
    }

    function edgeRoute(edge, occupiedRoutes = []): var {
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
        const fromCenterX = fromX + root.nodeWidth / 2
        const fromCenterY = fromY + root.nodeHeight / 2
        const toCenterX = toX + root.nodeWidth / 2
        const toCenterY = toY + root.nodeHeight / 2
        const separatedRight = toX >= fromRight
        const separatedLeft = toRight <= fromX
        const vertical = !separatedRight && !separatedLeft
        const primaryDirection = vertical
            ? (toCenterY >= fromCenterY ? 1 : -1)
            : (separatedRight ? 1 : -1)
        const laneOffset = root.edgeLaneOffset(
            edge, vertical, primaryDirection)
        const candidates = []
        const bounds = root.rawNodeBounds()

        if (!vertical) {
            const rightward = separatedRight
            const direction = rightward ? 1 : -1
            const x0 = fromX + (rightward ? root.nodeWidth : 0)
            const y0 = fromCenterY
            const x3 = toX + (rightward ? 0 : root.nodeWidth)
            const y3 = toCenterY
            const targetLabelRun = Math.min(
                84, Math.max(60, Math.abs(x3 - x0) * 0.45))
            const baseCorridor = x3
                - direction * targetLabelRun
                + laneOffset * 0.5
            const corridorOffsets = [0, 32, -32, 64, -64, 120, -120]
            for (const offset of corridorOffsets) {
                const corridor = baseCorridor + offset
                candidates.push(root.routeFromPoints([
                    { x: x0, y: y0 },
                    { x: corridor, y: y0 },
                    { x: corridor, y: y3 },
                    { x: x3, y: y3 }
                ], false, direction))
            }

            const stub = 36
            const fromStub = x0 + direction * stub
            const toStub = x3 - direction * stub
            const middleY = (y0 + y3) / 2
            const yLanes = [
                bounds.minY - 52 - Math.abs(laneOffset) * 0.25,
                bounds.maxY + 52 + Math.abs(laneOffset) * 0.25,
                middleY + 120,
                middleY - 120,
                middleY + 220,
                middleY - 220
            ]
            for (const laneY of yLanes) {
                candidates.push(root.routeFromPoints([
                    { x: x0, y: y0 },
                    { x: fromStub, y: y0 },
                    { x: fromStub, y: laneY },
                    { x: toStub, y: laneY },
                    { x: toStub, y: y3 },
                    { x: x3, y: y3 }
                ], false, direction))
            }

            // If an intervening node blocks both horizontal stubs, switch to
            // top/bottom ports and route through an outer horizontal lane.
            const horizontalPortLanes = [
                {
                    sourceY: fromY,
                    targetY: toY,
                    laneY: bounds.minY - 52 - Math.abs(laneOffset) * 0.25
                },
                {
                    sourceY: fromY + root.nodeHeight,
                    targetY: toY + root.nodeHeight,
                    laneY: bounds.maxY + 52 + Math.abs(laneOffset) * 0.25
                }
            ]
            for (const portLane of horizontalPortLanes) {
                candidates.push(root.routeFromPoints([
                    { x: fromCenterX, y: portLane.sourceY },
                    { x: fromCenterX, y: portLane.laneY },
                    { x: toCenterX, y: portLane.laneY },
                    { x: toCenterX, y: portLane.targetY }
                ], false, direction))
            }

            // Backward/long connections may still cut across an occupied
            // corridor even when they avoid every node. Give the router two
            // full-perimeter candidates that enter the target from the graph's
            // outer side, matching the "reroute around the tree" pattern used
            // by mature node editors without inventing a semantic IR node.
            const outerX = rightward
                ? bounds.maxX + 52 : bounds.minX - 52
            const targetOuterX = rightward ? toRight : toX
            const perimeterPortLanes = [
                {
                    sourceY: fromY,
                    laneY: bounds.minY - 52
                },
                {
                    sourceY: fromY + root.nodeHeight,
                    laneY: bounds.maxY + 52
                }
            ]
            for (const portLane of perimeterPortLanes) {
                candidates.push(root.routeFromPoints([
                    { x: fromCenterX, y: portLane.sourceY },
                    { x: fromCenterX, y: portLane.laneY },
                    { x: outerX, y: portLane.laneY },
                    { x: outerX, y: toCenterY },
                    { x: targetOuterX, y: toCenterY }
                ], false, direction))
            }
        } else {
            const downward = toCenterY >= fromCenterY
            const direction = downward ? 1 : -1
            const x0 = fromCenterX
            const y0 = fromY + (downward ? root.nodeHeight : 0)
            const x3 = toCenterX
            const y3 = toY + (downward ? 0 : root.nodeHeight)
            const baseCorridor = (y0 + y3) / 2 + laneOffset
            const corridorOffsets = [0, 48, -48, 96, -96, 160, -160]
            for (const offset of corridorOffsets) {
                const corridor = baseCorridor + offset
                candidates.push(root.routeFromPoints([
                    { x: x0, y: y0 },
                    { x: x0, y: corridor },
                    { x: x3, y: corridor },
                    { x: x3, y: y3 }
                ], true, direction))
            }

            const stub = 36
            const fromStub = y0 + direction * stub
            const toStub = y3 - direction * stub
            const middleX = (x0 + x3) / 2
            const xLanes = [
                bounds.minX - 52 - Math.abs(laneOffset) * 0.25,
                bounds.maxX + 52 + Math.abs(laneOffset) * 0.25,
                middleX + 120,
                middleX - 120,
                middleX + 220,
                middleX - 220
            ]
            for (const laneX of xLanes) {
                candidates.push(root.routeFromPoints([
                    { x: x0, y: y0 },
                    { x: x0, y: fromStub },
                    { x: laneX, y: fromStub },
                    { x: laneX, y: toStub },
                    { x: x3, y: toStub },
                    { x: x3, y: y3 }
                ], true, direction))
            }

            // Same-column stacks can have an intermediate node directly in
            // front of the top/bottom port. In that case, switch to a side
            // port before taking the outer lane instead of drawing through it.
            const verticalPortLanes = [
                {
                    sourceX: fromX,
                    targetX: toX,
                    laneX: bounds.minX - 52 - Math.abs(laneOffset) * 0.25
                },
                {
                    sourceX: fromRight,
                    targetX: toRight,
                    laneX: bounds.maxX + 52 + Math.abs(laneOffset) * 0.25
                }
            ]
            for (const portLane of verticalPortLanes) {
                candidates.push(root.routeFromPoints([
                    { x: portLane.sourceX, y: fromCenterY },
                    { x: portLane.laneX, y: fromCenterY },
                    { x: portLane.laneX, y: toCenterY },
                    { x: portLane.targetX, y: toCenterY }
                ], true, direction))
            }
        }

        let bestRoute = null
        let bestScore = Number.POSITIVE_INFINITY
        for (const candidate of candidates) {
            if (!candidate)
                continue
            const score = root.routeScore(
                candidate, edge, occupiedRoutes)
            if (score < bestScore) {
                bestRoute = candidate
                bestScore = score
            }
        }
        if (bestRoute) {
            bestRoute.edgeId = String(edge?.id ?? "")
            bestRoute.fromId = String(edge?.from ?? "")
            bestRoute.toId = String(edge?.to ?? "")
            // Route geometry is immutable until the route cache is rebuilt.
            // Cache its AABB once so viewport culling and 60 Hz pointer hit
            // testing do not rescan every route point.
            bestRoute.bounds = root.routeBounds(bestRoute)
        }
        return bestRoute
    }

    function buildEdgeRouteCache(): var {
        const cache = ({})
        const occupiedRoutes = []
        const graph = root.graph
        for (const edge of (graph?.edges ?? [])) {
            const edgeId = String(edge?.id ?? "")
            if (edgeId.length === 0)
                continue
            const route = root.edgeRoute(edge, occupiedRoutes)
            cache[edgeId] = route
            if (route)
                occupiedRoutes.push(route)
        }
        return cache
    }

    function rebuildEdgeRouteCache(): void {
        if (!root.workflowActive)
            return
        if (root.activeNodeDragId.length > 0)
            return
        root.edgeRouteCache = root.buildEdgeRouteCache()
        root.refreshGeometryCache()
    }

    function scheduleEdgeRouteCacheRebuild(): void {
        if (!root.workflowActive || root.activeNodeDragId.length > 0)
            return
        edgeRouteRebuildTimer.restart()
    }

    Timer {
        id: edgeRouteRebuildTimer
        interval: 0
        repeat: false
        onTriggered: root.rebuildEdgeRouteCache()
    }

    function edgeTouchesNode(edge, nodeId: string): bool {
        const id = String(nodeId ?? "")
        return id.length > 0
            && (String(edge?.from ?? "") === id
                || String(edge?.to ?? "") === id)
    }

    function rebuildDragEdgeRouteCache(): void {
        const nodeId = root.activeNodeDragId
        if (nodeId.length === 0) {
            root.dragEdgeRouteCache = ({})
            root.dragRoutesDirty = false
            return
        }

        const cache = ({})
        const occupiedRoutes = []
        // Reuse stable routes for unrelated edges. They do not need expensive
        // candidate scoring for every pointer sample.
        for (const edge of root.edges) {
            if (root.edgeTouchesNode(edge, nodeId))
                continue
            const edgeId = String(edge?.id ?? "")
            const route = root.edgeRouteCache[edgeId] ?? null
            if (route)
                occupiedRoutes.push(route)
        }

        // Attached edges still use the full smart-lane scorer, including
        // obstacle/crossing/overlap penalties, against stable unrelated routes.
        for (const edge of root.edges) {
            if (!root.edgeTouchesNode(edge, nodeId))
                continue
            const edgeId = String(edge?.id ?? "")
            if (edgeId.length === 0)
                continue
            const route = root.edgeRoute(edge, occupiedRoutes)
            cache[edgeId] = route
            if (route)
                occupiedRoutes.push(route)
        }
        root.dragEdgeRouteCache = cache
        root.dragRoutesDirty = false
    }

    function routeForEdge(edge): var {
        const edgeId = String(edge?.id ?? "")
        if (edgeId.length === 0)
            return root.edgeRoute(edge)

        const dragNodeId = root.activeNodeDragId
        if (dragNodeId.length > 0
                && root.edgeTouchesNode(edge, dragNodeId)) {
            const preview = root.dragEdgeRouteCache[edgeId]
            if (preview)
                return preview
        }

        const cached = root.edgeRouteCache[edgeId]
        return cached ?? root.edgeRoute(edge)
    }

    function routeDiagnostics(): var {
        const occupiedRoutes = []
        let collisions = 0
        let crossings = 0
        let overlapLength = 0
        let maxBends = 0
        let totalLength = 0
        let routedEdges = 0

        for (const edge of root.edges) {
            const route = root.routeForEdge(edge)
            if (!route)
                continue
            routedEdges += 1
            collisions += root.routeCollisionCount(route, edge)
            crossings += root.routeCrossingCount(route, occupiedRoutes)
            overlapLength += root.routeOverlapLength(
                route, edge, occupiedRoutes)
            maxBends = Math.max(
                maxBends,
                Math.max(0, (route.points?.length ?? 2) - 2))
            totalLength += root.routeLength(route)
            occupiedRoutes.push(route)
        }

        return {
            style: "smooth-step-lane-v2",
            edges: root.edges.length,
            routedEdges: routedEdges,
            collisions: collisions,
            crossings: crossings,
            overlapLength: Math.round(overlapLength),
            maxBends: maxBends,
            totalLength: Math.round(totalLength)
        }
    }

    function computeGraphBounds(): var {
        if (root.nodes.length === 0)
            return {
                x: 0, y: 0,
                width: root.cachedWorldWidth,
                height: root.cachedWorldHeight
            }

        let minX = Number.POSITIVE_INFINITY
        let minY = Number.POSITIVE_INFINITY
        let maxX = Number.NEGATIVE_INFINITY
        let maxY = Number.NEGATIVE_INFINITY

        for (const node of root.nodes) {
            const x = root.nodeX(node)
            const y = root.nodeY(node)
            minX = Math.min(minX, x)
            minY = Math.min(minY, y)
            maxX = Math.max(maxX, x + root.nodeWidth)
            maxY = Math.max(maxY, y + root.nodeHeight)
        }

        // Section labels and backgrounds belong to the same fitted board.
        for (const group of root.groups) {
            minX = Math.min(minX, Number(group.x ?? 0))
            minY = Math.min(minY, Number(group.y ?? 0))
            maxX = Math.max(maxX,
                Number(group.x ?? 0) + Number(group.width ?? 0))
            maxY = Math.max(maxY,
                Number(group.y ?? 0) + Number(group.height ?? 0))
        }

        // Fit the same geometry that the renderer and hit-test use.
        for (const edge of root.edges) {
            const route = root.routeForEdge(edge)
            if (!route)
                continue
            const bounds = root.routeBounds(route)
            minX = Math.min(minX, bounds.minX)
            minY = Math.min(minY, bounds.minY)
            maxX = Math.max(maxX, bounds.maxX)
            maxY = Math.max(maxY, bounds.maxY)
        }

        return {
            x: minX,
            y: minY,
            width: Math.max(1, maxX - minX),
            height: Math.max(1, maxY - minY)
        }
    }

    function refreshGeometryCache(): void {
        root.cachedWorldWidth = root.graphExtent("x", 1050)
        root.cachedWorldHeight = root.graphExtent("y", 570)
        root.graphBoundsCache = root.computeGraphBounds()
    }

    function graphBounds(): var {
        return root.graphBoundsCache
    }

    function reasoningBounds(): var {
        if (!root.hasReasoningSelection)
            return null

        let minX = Number.POSITIVE_INFINITY
        let minY = Number.POSITIVE_INFINITY
        let maxX = Number.NEGATIVE_INFINITY
        let maxY = Number.NEGATIVE_INFINITY
        for (const nodeId of root.reasoningNodeIds) {
            const node = root.nodeById(String(nodeId ?? ""))
            if (!node)
                continue
            minX = Math.min(minX, Number(node.x ?? 0))
            minY = Math.min(minY, Number(node.y ?? 0))
            maxX = Math.max(maxX, Number(node.x ?? 0) + root.nodeWidth)
            maxY = Math.max(maxY, Number(node.y ?? 0) + root.nodeHeight)
        }
        for (const edgeId of root.reasoningEdgeIds) {
            const edge = root.edges.find(item =>
                String(item?.id ?? "") === String(edgeId ?? ""))
            const route = root.routeForEdge(edge)
            if (!route)
                continue
            const bounds = root.routeBounds(route)
            minX = Math.min(minX, bounds.minX)
            minY = Math.min(minY, bounds.minY)
            maxX = Math.max(maxX, bounds.maxX)
            maxY = Math.max(maxY, bounds.maxY)
        }
        if (!Number.isFinite(minX) || !Number.isFinite(minY)
                || !Number.isFinite(maxX) || !Number.isFinite(maxY))
            return null
        return {
            x: minX,
            y: minY,
            width: Math.max(1, maxX - minX),
            height: Math.max(1, maxY - minY)
        }
    }

    function fitBounds(bounds, margin: real, maximumZoom: real): void {
        if (!bounds || root.width <= 0 || root.height <= 0)
            return
        const safeMargin = Math.max(0, Number(margin))
        const availableWidth = Math.max(1, root.width - safeMargin * 2)
        const availableHeight = Math.max(1, root.height - safeMargin * 2)
        const nextZoom = Math.max(
            CodeWorkflowSession.minimumZoom,
            Math.min(
                Number(maximumZoom),
                availableWidth / Math.max(1, Number(bounds.width ?? 1)),
                availableHeight / Math.max(1, Number(bounds.height ?? 1))))
        CodeWorkflowSession.setViewport(
            (root.width - Number(bounds.width ?? 1) * nextZoom) / 2
                - Number(bounds.x ?? 0) * nextZoom,
            (root.height - Number(bounds.height ?? 1) * nextZoom) / 2
                - Number(bounds.y ?? 0) * nextZoom,
            nextZoom)
    }

    function fitSelection(): void {
        if (!root.workflowActive)
            return
        if (root.hasReasoningSelection) {
            root.fitBounds(root.reasoningBounds(), 36, 1.6)
            return
        }

        if (CodeWorkflowSession.selectedEdgeId.length > 0) {
            const edge = root.edges.find(item =>
                String(item?.id ?? "") === CodeWorkflowSession.selectedEdgeId)
            const route = root.routeForEdge(edge)
            if (route) {
                const routeBox = root.routeBounds(route)
                root.fitBounds({
                    x: routeBox.minX,
                    y: routeBox.minY,
                    width: Math.max(1, routeBox.maxX - routeBox.minX),
                    height: Math.max(1, routeBox.maxY - routeBox.minY)
                }, 42, 1.8)
            }
            return
        }

        if (CodeWorkflowSession.selectedSemanticAnchor.length > 0)
            return
        const node = root.nodeById(CodeWorkflowSession.selectedNodeId)
        if (node) {
            root.fitBounds({
                x: Number(node.x ?? 0),
                y: Number(node.y ?? 0),
                width: root.nodeWidth,
                height: root.nodeHeight
            }, 54, 1.8)
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

    function routeDistance(route, px: real, py: real): real {
        const points = route?.points ?? []
        if (points.length < 2)
            return 1e9

        let best = 1e9
        for (let index = 1; index < points.length; ++index) {
            best = Math.min(best, root.pointSegmentDistance(
                px, py,
                points[index - 1].x, points[index - 1].y,
                points[index].x, points[index].y))
        }
        return best
    }

    function edgeDistance(edge, px: real, py: real): real {
        return root.routeDistance(root.routeForEdge(edge), px, py)
    }

    function fitGraph(): void {
        if (!root.workflowActive)
            return
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

    function revealEdge(edgeId: string): void {
        const edge = root.edges.find(item =>
            String(item?.id ?? "") === String(edgeId ?? ""))
        const route = root.routeForEdge(edge)
        if (!edge || !route || root.width <= 0 || root.height <= 0)
            return

        const routeBounds = root.routeBounds(route)
        const minX = routeBounds.minX
        const minY = routeBounds.minY
        const maxX = routeBounds.maxX
        const maxY = routeBounds.maxY
        const boundsWidth = Math.max(1, maxX - minX)
        const boundsHeight = Math.max(1, maxY - minY)
        const margin = 40
        const availableWidth = Math.max(1, root.width - margin * 2)
        const availableHeight = Math.max(1, root.height - margin * 2)
        const currentZoom = Math.max(
            CodeWorkflowSession.minimumZoom,
            CodeWorkflowSession.zoom)
        const nextZoom = Math.max(
            CodeWorkflowSession.minimumZoom,
            Math.min(
                currentZoom,
                availableWidth / boundsWidth,
                availableHeight / boundsHeight))

        if (Math.abs(nextZoom - currentZoom) > 0.001) {
            CodeWorkflowSession.setViewport(
                (root.width - boundsWidth * nextZoom) / 2
                    - minX * nextZoom,
                (root.height - boundsHeight * nextZoom) / 2
                    - minY * nextZoom,
                nextZoom)
            return
        }

        const left = CodeWorkflowSession.panX + minX * nextZoom
        const top = CodeWorkflowSession.panY + minY * nextZoom
        const right = CodeWorkflowSession.panX + maxX * nextZoom
        const bottom = CodeWorkflowSession.panY + maxY * nextZoom
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
            CodeWorkflowSession.setViewport(nextX, nextY, nextZoom)
    }

    function revealPrimarySelection(): void {
        if (!root.workflowActive)
            return
        if (CodeWorkflowSession.selectedEdgeId.length > 0) {
            root.revealEdge(CodeWorkflowSession.selectedEdgeId)
            return
        }
        if (CodeWorkflowSession.selectedSemanticAnchor.length === 0)
            root.revealNode(CodeWorkflowSession.selectedNodeId)
    }

    function edgeStrokeWidth(selected: bool, highlighted: bool): real {
        const screenWidth = selected ? 2.8 : highlighted ? 2.5 : 1.1
        return screenWidth / Math.max(
            CodeWorkflowSession.minimumZoom, root.wireMetricZoom)
    }

    function edgeHaloWidth(focused: bool, hovered: bool): real {
        const screenWidth = focused ? 7.0 : hovered ? 4.0 : 2.4
        return screenWidth / Math.max(
            CodeWorkflowSession.minimumZoom, root.wireMetricZoom)
    }

    function scheduleWireMetricRefresh(): void {
        if (!root.workflowActive || wireMetricTimer.running)
            return
        wireMetricTimer.start()
    }

    Timer {
        id: wireMetricTimer
        interval: 48
        repeat: false
        onTriggered: {
            root.wireMetricZoom = Math.max(
                CodeWorkflowSession.minimumZoom,
                CodeWorkflowSession.zoom)
        }
    }

    function nodeAtWorld(px: real, py: real): bool {
        return root.nodes.some(node => {
            const x = root.nodeX(node)
            const y = root.nodeY(node)
            return px >= x && px <= x + root.nodeWidth
                && py >= y && py <= y + root.nodeHeight
        })
    }

    function nodeAtScreen(screenX: real, screenY: real): bool {
        const zoom = Math.max(0.0001, CodeWorkflowSession.zoom)
        return root.nodeAtWorld(
            (screenX - CodeWorkflowSession.panX) / zoom,
            (screenY - CodeWorkflowSession.panY) / zoom)
    }

    function viewportContains(screenX: real, screenY: real): bool {
        return screenX >= 0 && screenY >= 0
            && screenX <= root.width && screenY <= root.height
    }

    function itemPointInsideViewport(
        item, localX: real, localY: real
    ): bool {
        if (!item)
            return false
        const mapped = item.mapToItem(root, localX, localY)
        return root.viewportContains(mapped.x, mapped.y)
    }

    function setEdgeLabelHover(
        edgeId: string, item, localX: real, localY: real
    ): void {
        if (!item)
            return
        const mapped = item.mapToItem(root, localX, localY)
        if (!root.viewportContains(mapped.x, mapped.y)) {
            if (root.hoveredEdgeLabelId === edgeId)
                root.hoveredEdgeLabelId = ""
            return
        }
        root.hoveredEdgeLabelId = edgeId
        root.edgeLabelHoverX = mapped.x
        root.edgeLabelHoverY = mapped.y
    }

    function clearEdgeLabelHover(edgeId: string): void {
        if (root.hoveredEdgeLabelId === edgeId)
            root.hoveredEdgeLabelId = ""
    }

    function autoPanStep(position: real, extent: real): real {
        if (extent <= 0)
            return 0
        const margin = Math.min(64, Math.max(36, extent * 0.16))
        const maxStep = 12
        const gain = 0.24
        if (position < margin)
            return Math.min(maxStep, (margin - position) * gain)
        if (position > extent - margin)
            return -Math.min(
                maxStep, (position - (extent - margin)) * gain)
        return 0
    }

    function autoPanDraggedNode(): void {
        const handler = root.activeNodeDragHandler
        if (!handler || !handler.active)
            return

        // handlerPoint.scenePosition uses scene coordinates; mapFromItem(null)
        // converts them back into this clipped canvas coordinate system.
        const pointer = root.mapFromItem(
            null, root.activeNodeDragSceneX, root.activeNodeDragSceneY)
        const deltaX = root.autoPanStep(pointer.x, root.width)
        const deltaY = root.autoPanStep(pointer.y, root.height)
        if (Math.abs(deltaX) < 0.001 && Math.abs(deltaY) < 0.001)
            return

        CodeWorkflowSession.setViewportTransient(
            CodeWorkflowSession.panX + deltaX,
            CodeWorkflowSession.panY + deltaY,
            CodeWorkflowSession.zoom)
        handler.updateLayout()
    }

    function routeVisible(route, margin: real): bool {
        if (!route || !root.workflowActive)
            return false
        const bounds = root.routeBounds(route)
        const zoom = Math.max(
            CodeWorkflowSession.minimumZoom,
            CodeWorkflowSession.zoom)
        const padding = Math.max(0, Number(margin))
        const left = CodeWorkflowSession.panX + bounds.minX * zoom
        const top = CodeWorkflowSession.panY + bounds.minY * zoom
        const right = CodeWorkflowSession.panX + bounds.maxX * zoom
        const bottom = CodeWorkflowSession.panY + bounds.maxY * zoom
        return right >= -padding
            && bottom >= -padding
            && left <= root.width + padding
            && top <= root.height + padding
    }

    function edgeAt(screenX: real, screenY: real): string {
        if (!root.viewportContains(screenX, screenY))
            return ""
        const zoom = Math.max(0.0001, CodeWorkflowSession.zoom)
        const worldX = (screenX - CodeWorkflowSession.panX) / zoom
        const worldY = (screenY - CodeWorkflowSession.panY) / zoom
        if (root.nodeAtWorld(worldX, worldY))
            return ""

        const tolerance = 8 / zoom
        let bestId = ""
        let bestDistance = tolerance
        for (const edge of root.edges) {
            const route = root.routeForEdge(edge)
            if (!route)
                continue
            const bounds = root.routeBounds(route)
            if (worldX < bounds.minX - tolerance
                    || worldX > bounds.maxX + tolerance
                    || worldY < bounds.minY - tolerance
                    || worldY > bounds.maxY + tolerance)
                continue
            const distance = root.routeDistance(route, worldX, worldY)
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

    function edgeWireInk(
        kind: string, focused: bool, hovered: bool, halo: bool
    ): color {
        const ink = root.edgeInk(kind, focused || hovered)
        const alpha = halo
            ? (focused ? 0.20 : hovered ? 0.08 : 0.025)
            : (focused ? 0.94 : hovered ? 0.46 : 0.22)
        return ColorUtils.applyAlpha(ink, alpha)
    }

    Timer {
        id: viewportCommitTimer
        interval: 160
        repeat: false
        onTriggered: {
            if (root.workflowActive)
                CodeWorkflowSession.commitViewport()
        }
    }

    Timer {
        id: dragFrameTimer
        interval: 16
        repeat: true
        running: root.workflowActive
            && root.activeNodeDragHandler !== null
        onTriggered: {
            root.autoPanDraggedNode()
            if (root.dragRoutesDirty)
                root.rebuildDragEdgeRouteCache()
        }
    }

    WheelHandler {
        target: null
        enabled: root.activeNodeDragHandler === null
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
            CodeWorkflowSession.setViewportTransient(
                event.x - graphX * nextZoom,
                event.y - graphY * nextZoom,
                nextZoom)
            viewportCommitTimer.restart()
            event.accepted = true
        }
    }

    property real pendingEdgeHoverX: 0
    property real pendingEdgeHoverY: 0

    Timer {
        id: edgeHoverTimer
        interval: 16
        repeat: false
        onTriggered: {
            if (!root.workflowActive || !edgeHover.hovered
                    || canvasPanArea.pressed
                    || root.activeNodeDragHandler !== null
                    || pinch.active)
                return
            root.hoveredEdgeId = root.edgeAt(
                root.pendingEdgeHoverX, root.pendingEdgeHoverY)
        }
    }

    HoverHandler {
        id: edgeHover
        target: null
        enabled: root.workflowActive
            && !canvasPanArea.pressed
            && root.activeNodeDragHandler === null
            && !pinch.active

        onPointChanged: {
            root.pendingEdgeHoverX = point.position.x
            root.pendingEdgeHoverY = point.position.y
            edgeHoverTimer.restart()
        }
        onHoveredChanged: {
            if (!hovered) {
                edgeHoverTimer.stop()
                root.hoveredEdgeId = ""
            }
        }
    }

    TapHandler {
        id: edgeTap
        target: null
        acceptedButtons: Qt.LeftButton

        onTapped: (eventPoint, button) => {
            const edgeId = root.edgeAt(
                eventPoint.position.x, eventPoint.position.y)
            if (edgeId.length > 0) {
                const edge = root.edges.find(item => item.id === edgeId)
                CodeWorkflowSession.selectUnifiedEdge(edge)
            }
        }
    }

    Connections {
        target: CodeWorkflowSession
        enabled: root.workflowActive

        function onViewportInitializedChanged(): void {
            root.fitInitialGraph()
        }

        function onZoomChanged(): void {
            root.scheduleWireMetricRefresh()
        }

        function onSubflowTargetIdChanged(): void {
            root.marqueeActive = false
            root.marqueeBaseNodeIds = []
            root.clearMarqueeReasoningSnapshot()
            root.clearReasoningSelection()
            root.hoveredEdgeLabelId = ""
            root.activeNodeDragId = ""
            root.activeNodeDragHandler = null
            root.dragEdgeRouteCache = ({})
            // The inspected module changes; the shared canvas remains in
            // place. Revealing selection never resets pan or zoom.
            Qt.callLater(root.revealPrimarySelection)
        }

        function onGraphLayoutRevisionChanged(): void {
            root.rebuildNodeLayoutOffsetCache()
            root.scheduleEdgeRouteCacheRebuild()
        }

        function onSelectedNodeIdChanged(): void {
            root.clearReasoningSelection()
            Qt.callLater(root.revealPrimarySelection)
        }

        function onSelectedEdgeIdChanged(): void {
            root.clearReasoningSelection()
            Qt.callLater(root.revealPrimarySelection)
        }

        function onSelectedSemanticAnchorChanged(): void {
            root.clearReasoningSelection()
        }
    }

    PinchHandler {
        id: pinch
        target: null
        enabled: root.activeNodeDragHandler === null
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
            } else {
                CodeWorkflowSession.commitViewport()
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
            CodeWorkflowSession.setViewportTransient(
                centroid.position.x - pivot.x * nextZoom,
                centroid.position.y - pivot.y * nextZoom,
                nextZoom)
        }

        onActiveScaleChanged: updateViewport()
        onActiveTranslationChanged: updateViewport()
    }

    function activateCanvas(): void {
        if (!root.workflowActive)
            return
        // Keep a previously materialized graph across Settings page-cache
        // navigation. The parent Loader hides it while inactive and all
        // runtime/session listeners below are suspended; rebuilding dozens of
        // delegates on every revisit costs more than retaining this bounded
        // presentation cache until the Loader itself is evicted/destroyed.
        root.wireMetricZoom = Math.max(
            CodeWorkflowSession.minimumZoom,
            CodeWorkflowSession.zoom)
        graphRefreshTimer.restart()
        Qt.callLater(root.consumeRuntimeLifecycleEvent)
        root.fitInitialGraph()
    }

    function deactivateCanvas(): void {
        graphRefreshTimer.stop()
        edgeRouteRebuildTimer.stop()
        edgeHoverTimer.stop()
        wireMetricTimer.stop()
        initialFitTimer.stop()
        runtimePulseTimer.stop()
        viewportCommitTimer.stop()
        root.activeNodeDragId = ""
        root.activeNodeDragHandler = null
        root.dragRoutesDirty = false
        root.dragEdgeRouteCache = ({})
        root.runtimePulseTargetId = ""
        root.runtimePulseKind = ""
        // Keep graph/signature/route caches warm while this Settings Loader is
        // retained. They disappear naturally when SettingsPageHost evicts the
        // page or the Settings surface is destroyed.
    }

    Component.onCompleted: root.activateCanvas()

    onShowInternalsChanged: {
        if (root.workflowActive)
            root.refreshGraph(true)
    }

    onWorkflowActiveChanged: {
        if (root.workflowActive)
            root.activateCanvas()
        else
            root.deactivateCanvas()
    }

    onVisibleChanged: {
        if (visible && root.workflowActive)
            Qt.callLater(root.consumeRuntimeLifecycleEvent)
        else if (!visible) {
            runtimePulseTimer.stop()
            root.runtimePulseTargetId = ""
            root.runtimePulseKind = ""
        }
    }

    Connections {
        target: CodeWorkflowRuntime
        enabled: root.workflowActive
        function onRevisionChanged(): void {
            root.consumeRuntimeLifecycleEvent()
            graphRefreshTimer.restart()
        }
    }

    Connections {
        target: CodeWorkflowIr
        enabled: root.workflowActive
        function onDocumentChanged(): void {
            root.refreshGraph(true)
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Appearance.colors.colLayer0
        z: -2
    }

    MouseArea {
        id: canvasPanArea
        anchors.fill: parent
        // Keep the empty-space gesture surface above the transformed world.
        // Presses on nodes/edges are explicitly rejected below, so their own
        // handlers still receive input while true canvas space pans. Shift
        // reserves the same empty-space gesture for marquee graph reasoning.
        z: 2
        enabled: root.activeNodeDragHandler === null
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        preventStealing: true
        hoverEnabled: false
        cursorShape: root.marqueeActive
            ? Qt.CrossCursor
            : pressed ? Qt.ClosedHandCursor : Qt.ArrowCursor
        property real pressX: 0
        property real pressY: 0
        property real basePanX: 0
        property real basePanY: 0

        onPressed: mouse => {
            if (root.nodeAtScreen(mouse.x, mouse.y)
                    || root.edgeAt(mouse.x, mouse.y).length > 0) {
                mouse.accepted = false
                return
            }

            pressX = mouse.x
            pressY = mouse.y
            basePanX = CodeWorkflowSession.panX
            basePanY = CodeWorkflowSession.panY

            const shiftHeld = (mouse.modifiers & Qt.ShiftModifier) !== 0
            const controlHeld = (mouse.modifiers & Qt.ControlModifier) !== 0
            if (mouse.button === Qt.LeftButton && shiftHeld) {
                root.snapshotMarqueeReasoning()
                root.marqueeActive = true
                root.marqueeStartX = mouse.x
                root.marqueeStartY = mouse.y
                root.marqueeCurrentX = mouse.x
                root.marqueeCurrentY = mouse.y
                root.marqueeBaseNodeIds = controlHeld
                        && root.reasoningMode === "manual"
                    ? root.reasoningNodeIds.slice()
                    : []
                root.updateMarqueeSelection()
            }
        }
        onPositionChanged: mouse => {
            if (!pressed)
                return
            if (root.marqueeActive) {
                root.marqueeCurrentX = mouse.x
                root.marqueeCurrentY = mouse.y
                root.updateMarqueeSelection()
                return
            }
            CodeWorkflowSession.setViewportTransient(
                basePanX + mouse.x - pressX,
                basePanY + mouse.y - pressY,
                CodeWorkflowSession.zoom)
        }
        onReleased: mouse => {
            if (root.marqueeActive) {
                root.marqueeCurrentX = mouse.x
                root.marqueeCurrentY = mouse.y
                root.updateMarqueeSelection()
                root.marqueeActive = false
                root.marqueeBaseNodeIds = []
                root.clearMarqueeReasoningSnapshot()
                return
            }
            CodeWorkflowSession.commitViewport()
        }
        onCanceled: {
            if (root.marqueeActive) {
                root.marqueeActive = false
                root.marqueeBaseNodeIds = []
                root.restoreMarqueeReasoningSnapshot()
                return
            }
            CodeWorkflowSession.commitViewport()
        }
    }

    Rectangle {
        id: marqueeSelectionRect
        z: 20
        visible: root.marqueeActive
        x: Math.min(root.marqueeStartX, root.marqueeCurrentX)
        y: Math.min(root.marqueeStartY, root.marqueeCurrentY)
        width: Math.abs(root.marqueeCurrentX - root.marqueeStartX)
        height: Math.abs(root.marqueeCurrentY - root.marqueeStartY)
        radius: Appearance.rounding.small
        color: ColorUtils.applyAlpha(
            Appearance.colors.colPrimaryContainer, 0.24)
        border.width: 1
        border.color: Appearance.colors.colPrimary
    }

    Rectangle {
        id: minimap
        z: 30
        visible: root.minimapNeeded
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 12
        width: 172
        height: 112
        radius: Appearance.rounding.normal
        color: ColorUtils.applyAlpha(Appearance.colors.colLayer1, 0.94)
        border.width: 1
        border.color: Appearance.colors.colOutlineVariant
        clip: true

        readonly property real padding: 8
        readonly property var bounds: root.graphBounds()
        readonly property real scaleFactor: Math.max(
            0.0001,
            Math.min(
                (width - padding * 2) / Math.max(1, Number(bounds.width ?? 1)),
                (height - padding * 2) / Math.max(1, Number(bounds.height ?? 1))))
        readonly property real fittedWidth:
            Number(bounds.width ?? 1) * scaleFactor
        readonly property real fittedHeight:
            Number(bounds.height ?? 1) * scaleFactor
        readonly property real originX:
            padding + (width - padding * 2 - fittedWidth) / 2
                - Number(bounds.x ?? 0) * scaleFactor
        readonly property real originY:
            padding + (height - padding * 2 - fittedHeight) / 2
                - Number(bounds.y ?? 0) * scaleFactor

        function mapX(worldX: real): real {
            return minimap.originX + worldX * minimap.scaleFactor
        }

        function mapY(worldY: real): real {
            return minimap.originY + worldY * minimap.scaleFactor
        }

        Repeater {
            model: root.nodes

            delegate: Rectangle {
                required property var modelData
                readonly property string nodeId:
                    String(modelData?.id ?? "")
                x: minimap.mapX(root.nodeX(modelData))
                y: minimap.mapY(root.nodeY(modelData))
                width: Math.max(2, root.nodeWidth * minimap.scaleFactor)
                height: Math.max(2, root.nodeHeight * minimap.scaleFactor)
                radius: Math.min(3, height / 3)
                color: root.reasoningNodeIds.includes(nodeId)
                    ? Appearance.colors.colSecondary
                    : CodeWorkflowSession.selectedNodeId === nodeId
                        ? Appearance.colors.colPrimary
                        : Appearance.colors.colOutlineVariant
                opacity: root.reasoningNodeIds.includes(nodeId)
                    || CodeWorkflowSession.selectedNodeId === nodeId
                    ? 0.95 : 0.62
            }
        }

        Rectangle {
            id: minimapViewport
            z: 2
            readonly property real zoom: Math.max(
                CodeWorkflowSession.minimumZoom, CodeWorkflowSession.zoom)
            x: minimap.mapX(-CodeWorkflowSession.panX / zoom)
            y: minimap.mapY(-CodeWorkflowSession.panY / zoom)
            width: Math.max(2,
                root.width / zoom * minimap.scaleFactor)
            height: Math.max(2,
                root.height / zoom * minimap.scaleFactor)
            color: "transparent"
            border.width: 1
            border.color: Appearance.colors.colPrimary
            radius: 2
        }

        MouseArea {
            anchors.fill: parent
            z: 3
            acceptedButtons: Qt.LeftButton
            preventStealing: true
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.PointingHandCursor

            function recenterAt(px: real, py: real): void {
                const worldX = (px - minimap.originX)
                    / minimap.scaleFactor
                const worldY = (py - minimap.originY)
                    / minimap.scaleFactor
                const zoom = Math.max(
                    CodeWorkflowSession.minimumZoom,
                    CodeWorkflowSession.zoom)
                CodeWorkflowSession.setViewportTransient(
                    root.width / 2 - worldX * zoom,
                    root.height / 2 - worldY * zoom,
                    zoom)
            }

            onPressed: mouse => recenterAt(mouse.x, mouse.y)
            onPositionChanged: mouse => {
                if (pressed)
                    recenterAt(mouse.x, mouse.y)
            }
            onReleased: CodeWorkflowSession.commitViewport()
            onCanceled: CodeWorkflowSession.commitViewport()
        }
    }

    Item {
        id: world
        width: root.worldWidth
        height: root.worldHeight
        x: CodeWorkflowSession.panX
        y: CodeWorkflowSession.panY
        scale: CodeWorkflowSession.zoom
        transformOrigin: Item.TopLeft

        // Source-reviewed groups and lifecycle declarations share the same
        // transform, viewport, pan/zoom and node interaction surface.
        Repeater {
            model: root.groups
            delegate: Rectangle {
                required property var modelData
                x: modelData.x
                y: modelData.y
                width: modelData.width
                height: modelData.height
                radius: Appearance.rounding.normal
                color: "transparent"
                border.width: 1
                border.color: ColorUtils.applyAlpha(
                    Appearance.colors.colOutlineVariant, 0.45)
                z: -1
                GraphText {
                    x: 12
                    y: 8
                    text: modelData.title
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.DemiBold
                }
            }
        }

        Repeater {
            model: root.edges

            delegate: Shape {
                id: edgeShape
                required property var modelData

                readonly property bool endpointsPresent:
                    !!root.nodeIndexCache[String(modelData.from ?? "")]
                    && !!root.nodeIndexCache[String(modelData.to ?? "")]
                readonly property var route:
                    root.routeForEdge(modelData)
                readonly property bool selectedEdge:
                    CodeWorkflowSession.selectedEdgeId === modelData.id
                readonly property bool hoveredEdge:
                    root.hoveredEdgeId === modelData.id
                readonly property bool reasoningEdge:
                    root.reasoningEdgeIds.includes(String(modelData.id ?? ""))
                readonly property bool highlighted:
                    selectedEdge
                    || reasoningEdge
                    || (CodeWorkflowSession.selectedEdgeId.length === 0
                        && CodeWorkflowSession.selectedSemanticAnchor.length === 0
                        && (CodeWorkflowSession.selectedNodeId
                                === modelData.from
                            || CodeWorkflowSession.selectedNodeId
                                === modelData.to))

                anchors.fill: parent
                // Qt's scene graph does not CPU-cull arbitrary offscreen
                // primitives. Hide route Shapes outside the viewport so zoomed
                // detail views do not keep submitting the whole graph.
                visible: edgeShape.endpointsPresent
                    && root.routeVisible(edgeShape.route, 48)
                // Phase-0's retained 600-second renderer soak qualified the
                // generic geometry path while CurveRenderer remained HOLD for
                // sustained RSS growth. Keep preprocessing asynchronous so
                // triangulation does not block the Settings GUI thread.
                preferredRendererType: Shape.GeometryRenderer
                antialiasing: true
                asynchronous: true
                // Shared endpoint trunks are intentional. Lift the active
                // relation above sibling wires without painting over labels
                // (z 0.5) or nodes (z 1).
                z: selectedEdge ? 0.4 : reasoningEdge ? 0.35
                    : hoveredEdge ? 0.3 : 0

                // EQ/DSP-inspired cable: a broad, very faint sheath sits
                // behind a narrow conductor. Only the focused relation carries
                // enough luminance to dominate the graph.
                ShapePath {
                    id: edgeHaloPath
                    readonly property var route: edgeShape.route

                    strokeColor: root.edgeWireInk(
                        edgeShape.modelData.kind,
                        edgeShape.highlighted,
                        edgeShape.hoveredEdge,
                        true)
                    strokeWidth: root.edgeHaloWidth(
                        edgeShape.highlighted,
                        edgeShape.hoveredEdge)
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin
                    fillColor: "transparent"
                    PathSvg {
                        path: edgeHaloPath.route?.svg ?? ""
                    }
                }

                ShapePath {
                    id: edgePath
                    readonly property var route: edgeHaloPath.route

                    strokeColor: root.edgeWireInk(
                        edgeShape.modelData.kind,
                        edgeShape.highlighted,
                        edgeShape.hoveredEdge,
                        false)
                    strokeWidth: root.edgeStrokeWidth(
                        edgeShape.selectedEdge,
                        edgeShape.highlighted)
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin
                    fillColor: "transparent"
                    PathSvg {
                        path: edgePath.route?.svg ?? ""
                    }
                }

                ShapePath {
                    id: arrowPath
                    readonly property var route: edgePath.route
                    readonly property var points: route?.points ?? []
                    readonly property var tipPoint: points.length > 0
                        ? points[points.length - 1] : ({ x: 0, y: 0 })
                    readonly property var previousPoint: points.length > 1
                        ? points[points.length - 2] : ({ x: -1, y: 0 })
                    readonly property real tipX: Number(tipPoint.x ?? 0)
                    readonly property real tipY: Number(tipPoint.y ?? 0)
                    readonly property real tangentX:
                        tipX - Number(previousPoint.x ?? tipX - 1)
                    readonly property real tangentY:
                        tipY - Number(previousPoint.y ?? tipY)
                    readonly property real tangentLength:
                        Math.max(0.001, Math.sqrt(
                            tangentX * tangentX
                            + tangentY * tangentY))
                    readonly property real unitX: tangentX / tangentLength
                    readonly property real unitY: tangentY / tangentLength
                    readonly property real screenArrowLength: 10
                    readonly property real screenArrowHalfWidth: 5
                    readonly property real worldArrowLength:
                        screenArrowLength / Math.max(
                            CodeWorkflowSession.minimumZoom,
                            root.wireMetricZoom)
                    readonly property real worldArrowHalfWidth:
                        screenArrowHalfWidth / Math.max(
                            CodeWorkflowSession.minimumZoom,
                            root.wireMetricZoom)
                    readonly property real backX:
                        tipX - unitX * worldArrowLength
                    readonly property real backY:
                        tipY - unitY * worldArrowLength
                    readonly property color ink: root.edgeWireInk(
                        edgeShape.modelData.kind,
                        edgeShape.highlighted,
                        edgeShape.hoveredEdge,
                        false)

                    strokeColor: "transparent"
                    fillColor: ink
                    startX: tipX
                    startY: tipY

                    PathLine {
                        x: arrowPath.backX - arrowPath.unitY * arrowPath.worldArrowHalfWidth
                        y: arrowPath.backY + arrowPath.unitX * arrowPath.worldArrowHalfWidth
                    }
                    PathLine {
                        x: arrowPath.backX + arrowPath.unitY * arrowPath.worldArrowHalfWidth
                        y: arrowPath.backY - arrowPath.unitX * arrowPath.worldArrowHalfWidth
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

                readonly property bool endpointsPresent:
                    !!root.nodeIndexCache[String(modelData.from ?? "")]
                    && !!root.nodeIndexCache[String(modelData.to ?? "")]
                readonly property var route:
                    root.routeForEdge(modelData)
                readonly property real midX:
                    Number(route?.labelX ?? 0)
                readonly property real midY:
                    Number(route?.labelY ?? 0)
                readonly property real labelWidthLimit:
                    route?.labelHorizontal === true
                        ? Math.max(24, Number(route?.labelSpan ?? 150) - 20)
                        : 150
                readonly property bool hovered:
                    (edgeLabelHover.hovered
                        && root.itemPointInsideViewport(
                            edgeLabel,
                            edgeLabelHover.point.position.x,
                            edgeLabelHover.point.position.y))
                    || root.hoveredEdgeId === String(modelData.id ?? "")

                visible: edgeLabel.endpointsPresent
                    && String(modelData.label ?? "").length > 0
                    && root.routeVisible(route, 80)
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

                    onPointChanged: {
                        if (!hovered)
                            return
                        root.setEdgeLabelHover(
                            String(edgeLabel.modelData.id ?? ""),
                            edgeLabel,
                            point.position.x,
                            point.position.y)
                    }
                    onHoveredChanged: {
                        const edgeId = String(
                            edgeLabel.modelData.id ?? "")
                        if (!hovered) {
                            root.clearEdgeLabelHover(edgeId)
                            return
                        }
                        root.setEdgeLabelHover(
                            edgeId,
                            edgeLabel,
                            point.position.x,
                            point.position.y)
                    }
                }

                GraphText {
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
                    CodeWorkflowSession.selectedEdgeId.length === 0
                    && CodeWorkflowSession.selectedSemanticAnchor.length === 0
                    && CodeWorkflowSession.selectedNodeId === modelData.id
                readonly property bool reasoningSelected:
                    root.reasoningNodeIds.includes(String(modelData.id ?? ""))
                readonly property bool runtimePulseActive:
                    root.nodeMatchesRuntimeTarget(
                        modelData, root.runtimePulseTargetId)
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

                x: root.nodeX(modelData)
                y: root.nodeY(modelData)
                width: root.nodeWidth
                height: root.nodeHeight
                radius: Appearance.rounding.normal
                color: selected
                    ? Appearance.colors.colPrimaryContainer
                    : Appearance.colors.colLayer1
                border.width: selected || reasoningSelected || activeFocus ? 2 : 1
                border.color: selected || activeFocus
                    ? accent
                    : reasoningSelected
                        ? Appearance.colors.colSecondary
                        : Appearance.colors.colOutlineVariant
                z: nodeDrag.active ? 1.4 : 1
                scale: nodeDrag.active ? 1.025 : 1
                transformOrigin: Item.Center
                activeFocusOnTab: true

                Behavior on scale {
                    NumberAnimation {
                        duration: 110
                        easing.type: Easing.OutCubic
                    }
                }

                HoverHandler {
                    cursorShape: nodeDrag.active
                        ? Qt.ClosedHandCursor : Qt.ArrowCursor
                }

                Accessible.role: Accessible.Button
                Accessible.name: modelData.title
                    + " · " + modelData.kind
                Accessible.description:
                    modelData.description ?? "Read-only workflow node"
                Accessible.focusable: true
                Accessible.onPressAction: {
                    CodeWorkflowSession.selectUnifiedNode(node.modelData)
                }

                DragHandler {
                    id: nodeDrag
                    target: null
                    acceptedButtons: Qt.LeftButton
                    dragThreshold: 3
                    property real baseOffsetX: 0
                    property real baseOffsetY: 0
                    property real startSceneX: 0
                    property real startSceneY: 0
                    property real startPanX: 0
                    property real startPanY: 0

                    function updateLayout(): void {
                        if (!active)
                            return
                        const zoom = Math.max(
                            0.0001, CodeWorkflowSession.zoom)
                        const baseX = Number(node.modelData.x ?? 0)
                        const baseY = Number(node.modelData.y ?? 0)
                        const panDeltaX =
                            CodeWorkflowSession.panX - startPanX
                        const panDeltaY =
                            CodeWorkflowSession.panY - startPanY
                        const deltaX =
                            (root.activeNodeDragSceneX - startSceneX
                                - panDeltaX) / zoom
                        const deltaY =
                            (root.activeNodeDragSceneY - startSceneY
                                - panDeltaY) / zoom
                        const nextX = Math.max(
                            20, baseX + baseOffsetX + deltaX)
                        const nextY = Math.max(
                            20, baseY + baseOffsetY + deltaY)
                        root.activeNodeDragOffsetX = nextX - baseX
                        root.activeNodeDragOffsetY = nextY - baseY
                        root.dragRoutesDirty = true
                    }

                    onActiveChanged: {
                        if (!active) {
                            if (root.activeNodeDragHandler === nodeDrag) {
                                const graphId =
                                    String(node.modelData.graphId
                                        ?? CodeWorkflowSession.subflowTargetId)
                                const nodeId = root.activeNodeDragId
                                const finalOffsetX =
                                    root.activeNodeDragOffsetX
                                const finalOffsetY =
                                    root.activeNodeDragOffsetY
                                CodeWorkflowSession.setNodeLayoutOffset(
                                    graphId, nodeId,
                                    finalOffsetX, finalOffsetY)
                                root.activeNodeDragHandler = null
                                root.activeNodeDragId = ""
                                root.dragRoutesDirty = false
                                root.dragEdgeRouteCache = ({})
                                root.scheduleEdgeRouteCacheRebuild()
                                CodeWorkflowSession.commitViewport()
                            }
                            return
                        }
                        const nodeId = String(node.modelData.id ?? "")
                        const offset = CodeWorkflowSession.nodeLayoutOffset(
                            String(node.modelData.graphId
                                ?? CodeWorkflowSession.subflowTargetId), nodeId)
                        baseOffsetX = Number(offset?.x ?? 0)
                        baseOffsetY = Number(offset?.y ?? 0)
                        startSceneX = centroid.scenePosition.x
                        startSceneY = centroid.scenePosition.y
                        startPanX = CodeWorkflowSession.panX
                        startPanY = CodeWorkflowSession.panY
                        root.activeNodeDragId = nodeId
                        root.activeNodeDragOffsetX = baseOffsetX
                        root.activeNodeDragOffsetY = baseOffsetY
                        root.activeNodeDragSceneX = startSceneX
                        root.activeNodeDragSceneY = startSceneY
                        root.activeNodeDragHandler = nodeDrag
                        root.dragRoutesDirty = true
                        root.rebuildDragEdgeRouteCache()
                        root.hoveredEdgeLabelId = ""
                        CodeWorkflowSession.selectUnifiedNode(node.modelData)
                        node.forceActiveFocus()
                    }
                    onCentroidChanged: {
                        if (!active)
                            return
                        root.activeNodeDragSceneX =
                            centroid.scenePosition.x
                        root.activeNodeDragSceneY =
                            centroid.scenePosition.y
                        updateLayout()
                    }
                }

                TapHandler {
                    id: nodeTap
                    onTapped: (eventPoint, button) => {
                        if (!root.itemPointInsideViewport(
                                node,
                                eventPoint.position.x,
                                eventPoint.position.y))
                            return
                        const additive = (nodeTap.point.modifiers
                                & (Qt.ControlModifier | Qt.ShiftModifier)) !== 0
                        if (additive)
                            root.toggleManualNodeSelection(node.modelData)
                        else
                            CodeWorkflowSession.selectUnifiedNode(node.modelData)
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

                    const additive = (event.modifiers
                            & (Qt.ControlModifier | Qt.ShiftModifier)) !== 0
                    if (additive)
                        root.toggleManualNodeSelection(node.modelData)
                    else
                        CodeWorkflowSession.selectUnifiedNode(node.modelData)
                    event.accepted = true
                }

                Rectangle {
                    id: runtimeLifecyclePulse
                    z: 4
                    visible: node.runtimePulseActive
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.rightMargin: 7
                    anchors.bottomMargin: 7
                    width: 9
                    height: 9
                    radius: width / 2
                    color: root.runtimePulseKind === "resident"
                        ? Appearance.colors.colPrimary
                        : Appearance.colors.colTertiary
                    border.width: 1
                    border.color: Appearance.colors.colLayer0

                    SequentialAnimation on scale {
                        running: runtimeLifecyclePulse.visible
                            && Appearance.animationsEnabled
                        loops: Animation.Infinite
                        NumberAnimation {
                            from: 0.75
                            to: 1.35
                            duration: 260
                            easing.type: Easing.OutCubic
                        }
                        NumberAnimation {
                            from: 1.35
                            to: 0.75
                            duration: 360
                            easing.type: Easing.InOutCubic
                        }
                    }
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

                            GraphText {
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

                        GraphText {
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
                                textRenderType: Text.QtRendering
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
                                    if (!root.itemPointInsideViewport(
                                            subflowAction,
                                            mouse.x, mouse.y))
                                        return
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

                    GraphText {
                        Layout.fillWidth: true
                        Layout.maximumWidth: node.width - 20
                        text: node.modelData.description ?? ""
                        color: node.subtext
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        elide: Text.ElideRight
                    }

                    GraphText {
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
        id: edgeLabelTooltip
        readonly property var hoveredEdge: root.edges.find(edge =>
            String(edge?.id ?? "") === root.hoveredEdgeLabelId) ?? null
        readonly property string labelText:
            String(hoveredEdge?.label ?? "")
        readonly property real viewportMargin: 6
        readonly property real desiredWidth:
            edgeLabelTooltipText.implicitWidth + 16

        visible: root.hoveredEdgeLabelId.length > 0
            && labelText.length > 0
        width: Math.max(0, Math.min(
            240,
            Math.max(0, root.width - viewportMargin * 2),
            desiredWidth))
        height: edgeLabelTooltipText.implicitHeight + 8
        x: Math.max(
            viewportMargin,
            Math.min(
                root.edgeLabelHoverX - width / 2,
                Math.max(
                    viewportMargin,
                    root.width - width - viewportMargin)))
        y: {
            const above = root.edgeLabelHoverY - height - 10
            if (above >= viewportMargin)
                return above
            return Math.min(
                root.edgeLabelHoverY + 10,
                Math.max(
                    viewportMargin,
                    root.height - height - viewportMargin))
        }
        radius: height / 2
        color: Appearance.colors.colLayer2
        border.width: 1
        border.color: Appearance.colors.colOutlineVariant
        z: 100
        clip: true

        StyledText {
            id: edgeLabelTooltipText
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            verticalAlignment: Text.AlignVCenter
            text: edgeLabelTooltip.labelText
            color: Appearance.colors.colOnLayer2
            font.pixelSize: Appearance.font.pixelSize.smallest
            elide: Text.ElideRight
            maximumLineCount: 1
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
