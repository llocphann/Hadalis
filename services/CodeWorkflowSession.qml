pragma Singleton
import QtQuick
import Quickshell
import qs.services
import qs.modules.common

Singleton {
    id: root

    property string selectedTargetId: "bar"
    property string selectedInstanceId: ""
    property string outputName: ""
    property string subflowTargetId: "bar"
    property string selectedNodeId: "bar.component"
    property string selectedEdgeId: ""
    property string selectedConnectTargetId: ""
    property string selectedSemanticAnchor: ""
    property string semanticAnchor: ""
    property string semanticAnchorNodeId: ""
    property real panX: 32
    property real panY: 28
    // Fit must include disconnected modules on the shared canvas. Users can
    // zoom in for inspection without losing the all-components overview.
    readonly property real minimumZoom: 0.015
    readonly property real maximumZoom: 2.5
    property real zoom: 1
    // Restored or user-changed viewport must survive Settings page eviction.
    property bool viewportInitialized: false
    property bool sourcePreviewVisible: true
    property real targetsPaneWidth: 224
    property real inspectorPaneWidth: 280
    property bool targetsPaneCollapsed: false
    property bool inspectorPaneCollapsed: false
    property real sourcePreviewHeight: 190
    property bool minimapEnabled: true
    property string pinnedTargetId: ""
    property var recentTargetIds: []
    readonly property int maximumRecentTargets: 8
    // Visual graph layout is presentation-only. It never mutates reviewed IR
    // or source. Persist it in workspace state so manual organization survives
    // Settings eviction and shell restarts.
    property var graphNodeLayoutOffsets: ({})
    property int graphLayoutRevision: 0
    readonly property real maximumNodeLayoutOffset: 100000
    property bool _restoring: false
    property bool _ready: false

    function _state(): var {
        return Persistent.states?.settings ?? null
    }

    function _sanitizeRecentTargetIds(raw): var {
        if (!Array.isArray(raw))
            return []
        const seen = ({})
        const safe = []
        for (const value of raw) {
            const targetId = String(value ?? "").trim()
            if (targetId.length === 0 || seen[targetId])
                continue
            seen[targetId] = true
            safe.push(targetId)
            if (safe.length >= root.maximumRecentTargets)
                break
        }
        return safe
    }

    function rememberTarget(targetId: string): void {
        const nextTargetId = String(targetId ?? "").trim()
        if (nextTargetId.length === 0
                || !CodeWorkflowRuntime.descriptor(nextTargetId))
            return
        root.recentTargetIds = [nextTargetId].concat(
            root.recentTargetIds.filter(id =>
                String(id ?? "") !== nextTargetId))
            .slice(0, root.maximumRecentTargets)
    }

    function togglePinnedTarget(targetId: string): bool {
        const nextTargetId = String(targetId ?? "").trim()
        if (nextTargetId.length === 0
                || !CodeWorkflowRuntime.descriptor(nextTargetId))
            return false
        root.pinnedTargetId = root.pinnedTargetId === nextTargetId
            ? "" : nextTargetId
        root.persist()
        return true
    }

    function _decodeGraphNodeLayoutOffsets(raw): var {
        const text = String(raw ?? "").trim()
        if (text.length === 0)
            return ({})

        let decoded
        try {
            decoded = JSON.parse(text)
        } catch (error) {
            return ({})
        }
        if (!decoded || typeof decoded !== "object" || Array.isArray(decoded))
            return ({})

        const safe = ({})
        for (const graphKey of Object.keys(decoded)) {
            if (!CodeWorkflowIr.hasGraph(graphKey))
                continue
            const rawGraph = decoded[graphKey]
            if (!rawGraph || typeof rawGraph !== "object"
                    || Array.isArray(rawGraph))
                continue

            const safeGraph = ({})
            for (const nodeKey of Object.keys(rawGraph)) {
                if (!CodeWorkflowIr.nodeFor(graphKey, nodeKey))
                    continue
                const rawOffset = rawGraph[nodeKey]
                const x = Number(rawOffset?.x)
                const y = Number(rawOffset?.y)
                if (!Number.isFinite(x) || !Number.isFinite(y))
                    continue
                safeGraph[nodeKey] = {
                    x: Math.max(-root.maximumNodeLayoutOffset, Math.min(
                        root.maximumNodeLayoutOffset, x)),
                    y: Math.max(-root.maximumNodeLayoutOffset, Math.min(
                        root.maximumNodeLayoutOffset, y))
                }
            }
            if (Object.keys(safeGraph).length > 0)
                safe[graphKey] = safeGraph
        }
        return safe
    }

    function restore(): void {
        if (!Persistent.ready || !CodeWorkflowIr.ready)
            return
        const runtimeInventoryReady =
            CodeWorkflowRuntime.hasLocalDeclarations
            || CodeWorkflowRuntime.remoteSnapshot !== null
            || CodeWorkflowRuntime.remoteError.length > 0
        if (!runtimeInventoryReady)
            return
        const state = root._state()
        if (!state)
            return

        root._restoring = true
        root.selectedTargetId = String(state.codeWorkflowTargetId ?? "bar") || "bar"
        root.selectedInstanceId = String(state.codeWorkflowInstanceId ?? "")
        root.outputName = String(state.codeWorkflowOutputName ?? "")
        root.subflowTargetId = String(
            state.codeWorkflowSubflowTargetId ?? "bar") || "bar"
        root.selectedNodeId = String(
            state.codeWorkflowNodeId ?? "bar.component") || "bar.component"
        root.selectedEdgeId = String(state.codeWorkflowEdgeId ?? "")
        root.selectedConnectTargetId = String(
            state.codeWorkflowConnectTargetId ?? "")
        root.selectedSemanticAnchor = ""
        if (!CodeWorkflowIr.hasGraph(root.subflowTargetId))
            root.subflowTargetId = "bar"
        if (!CodeWorkflowIr.nodeFor(root.subflowTargetId, root.selectedNodeId))
            root.selectedNodeId = CodeWorkflowIr.graphFor(
                root.subflowTargetId).rootNodeId ?? ""
        const restoredEdge = CodeWorkflowIr.edgeFor(
            root.subflowTargetId, root.selectedEdgeId)
        const restoredSignalAction =
            CodeWorkflowIr.reviewedSignalActionTargetForEdge(
                root.subflowTargetId, root.selectedEdgeId)
        if (!restoredEdge) {
            root.selectedEdgeId = ""
        } else if (restoredSignalAction !== null) {
            const actionNode = CodeWorkflowIr.nodeFor(
                root.subflowTargetId,
                String(restoredSignalAction.actionNodeId ?? ""))
            if (actionNode)
                root.selectedNodeId = actionNode.id
            else
                root.selectedEdgeId = ""
        } else {
            const edgeTarget = CodeWorkflowIr.nodeFor(
                root.subflowTargetId, String(restoredEdge.to ?? ""))
            if (!edgeTarget
                    || (restoredEdge.previewable === true
                        && edgeTarget.kind !== "binding")) {
                root.selectedEdgeId = ""
            } else {
                root.selectedNodeId = edgeTarget.id
            }
        }
        const restoredConnectTarget = CodeWorkflowIr.connectTargetFor(
            root.subflowTargetId, root.selectedConnectTargetId)
        if (!restoredConnectTarget
                || restoredConnectTarget.previewable !== false
                || restoredConnectTarget.editable !== false
                || restoredConnectTarget.typeCompatibility
                    !== "unknown-unresolved"
                || restoredConnectTarget.cycleStatus
                    !== "unknown-incomplete-projection") {
            root.selectedConnectTargetId = ""
        } else {
            const parentNode = CodeWorkflowIr.nodeFor(
                root.subflowTargetId,
                String(restoredConnectTarget.parentNodeId ?? ""))
            if (!parentNode) {
                root.selectedConnectTargetId = ""
            } else {
                root.selectedEdgeId = ""
                root.selectedNodeId = parentNode.id
            }
        }
        root.semanticAnchor = String(
            state.codeWorkflowSemanticAnchor ?? "")
        root.semanticAnchorNodeId = String(
            state.codeWorkflowSemanticAnchorNodeId ?? "")
        if (root.semanticAnchorNodeId !== root.selectedNodeId
                || root.selectedConnectTargetId.length > 0) {
            root.semanticAnchor = ""
            root.semanticAnchorNodeId = ""
        }
        root.viewportInitialized = state.codeWorkflowPanX !== undefined
            && state.codeWorkflowPanY !== undefined
            && state.codeWorkflowZoom !== undefined
        root.panX = Number(state.codeWorkflowPanX ?? 32)
        root.panY = Number(state.codeWorkflowPanY ?? 28)
        root.zoom = Math.max(root.minimumZoom, Math.min(
            root.maximumZoom,
            Number(state.codeWorkflowZoom ?? 1)))
        root.sourcePreviewVisible = state.codeWorkflowSourcePreview !== false
        root.targetsPaneWidth = Math.max(180, Math.min(
            420, Number(state.codeWorkflowTargetsPaneWidth ?? 224)))
        root.inspectorPaneWidth = Math.max(240, Math.min(
            520, Number(state.codeWorkflowInspectorPaneWidth ?? 280)))
        root.targetsPaneCollapsed =
            state.codeWorkflowTargetsPaneCollapsed === true
        root.inspectorPaneCollapsed =
            state.codeWorkflowInspectorPaneCollapsed === true
        root.sourcePreviewHeight = Math.max(120, Math.min(
            720, Number(state.codeWorkflowSourcePreviewHeight ?? 190)))
        root.minimapEnabled = state.codeWorkflowMinimap !== false
        root.pinnedTargetId = String(
            state.codeWorkflowPinnedTargetId ?? "").trim()
        root.recentTargetIds = root._sanitizeRecentTargetIds(
            state.codeWorkflowRecentTargetIds ?? [])
        root.graphNodeLayoutOffsets = root._decodeGraphNodeLayoutOffsets(
            state.codeWorkflowGraphNodeLayoutOffsets ?? "{}")
        root.graphLayoutRevision += 1
        root._restoring = false
        root._ready = true
    }

    function persist(): void {
        if (!root._ready || root._restoring || !Persistent.ready)
            return
        const state = root._state()
        if (!state)
            return

        state.codeWorkflowTargetId = root.selectedTargetId
        state.codeWorkflowInstanceId = root.selectedInstanceId
        state.codeWorkflowOutputName = root.outputName
        state.codeWorkflowSubflowTargetId = root.subflowTargetId
        state.codeWorkflowNodeId = root.selectedNodeId
        state.codeWorkflowEdgeId = root.selectedEdgeId
        state.codeWorkflowConnectTargetId = root.selectedConnectTargetId
        state.codeWorkflowSemanticAnchor = root.semanticAnchor
        state.codeWorkflowSemanticAnchorNodeId = root.semanticAnchorNodeId
        state.codeWorkflowPanX = root.panX
        state.codeWorkflowPanY = root.panY
        state.codeWorkflowZoom = root.zoom
        state.codeWorkflowSourcePreview = root.sourcePreviewVisible
        state.codeWorkflowTargetsPaneWidth = root.targetsPaneWidth
        state.codeWorkflowInspectorPaneWidth = root.inspectorPaneWidth
        state.codeWorkflowTargetsPaneCollapsed = root.targetsPaneCollapsed
        state.codeWorkflowInspectorPaneCollapsed = root.inspectorPaneCollapsed
        state.codeWorkflowSourcePreviewHeight = root.sourcePreviewHeight
        state.codeWorkflowMinimap = root.minimapEnabled
        state.codeWorkflowPinnedTargetId = root.pinnedTargetId
        state.codeWorkflowRecentTargetIds = root.recentTargetIds
        state.codeWorkflowGraphNodeLayoutOffsets = JSON.stringify(
            root.graphNodeLayoutOffsets ?? ({}))
    }

    function setTargetsPaneCollapsed(collapsed: bool): void {
        root.targetsPaneCollapsed = collapsed
        root.persist()
    }

    function setInspectorPaneCollapsed(collapsed: bool): void {
        root.inspectorPaneCollapsed = collapsed
        root.persist()
    }

    function nodeLayoutOffset(graphId: string, nodeId: string): var {
        root.graphLayoutRevision
        const graphKey = String(graphId ?? "")
        const nodeKey = String(nodeId ?? "")
        const graphOffsets = root.graphNodeLayoutOffsets[graphKey] ?? null
        const offset = graphOffsets?.[nodeKey] ?? null
        return offset ?? ({ x: 0, y: 0 })
    }

    function setNodeLayoutOffset(
        graphId: string, nodeId: string, x: real, y: real
    ): void {
        const graphKey = String(graphId ?? "")
        const nodeKey = String(nodeId ?? "")
        const nextX = Number(x)
        const nextY = Number(y)
        if (graphKey.length === 0 || nodeKey.length === 0
                || !CodeWorkflowIr.nodeFor(graphKey, nodeKey)
                || !Number.isFinite(nextX) || !Number.isFinite(nextY))
            return

        const boundedX = Math.max(-root.maximumNodeLayoutOffset, Math.min(
            root.maximumNodeLayoutOffset, nextX))
        const boundedY = Math.max(-root.maximumNodeLayoutOffset, Math.min(
            root.maximumNodeLayoutOffset, nextY))
        const nextAll = Object.assign({}, root.graphNodeLayoutOffsets)
        const nextGraph = Object.assign({}, nextAll[graphKey] ?? ({}))
        if (Math.abs(boundedX) < 0.001 && Math.abs(boundedY) < 0.001) {
            delete nextGraph[nodeKey]
            if (Object.keys(nextGraph).length === 0)
                delete nextAll[graphKey]
            else
                nextAll[graphKey] = nextGraph
        } else {
            nextGraph[nodeKey] = { x: boundedX, y: boundedY }
            nextAll[graphKey] = nextGraph
        }
        root.graphNodeLayoutOffsets = nextAll
        root.graphLayoutRevision += 1
        root.persist()
    }

    function hasGraphLayout(graphId: string): bool {
        root.graphLayoutRevision
        const graphKey = String(graphId ?? "")
        const graphOffsets = root.graphNodeLayoutOffsets[graphKey] ?? null
        return graphOffsets !== null
            && Object.keys(graphOffsets).length > 0
    }

    function resetGraphLayout(graphId: string): void {
        const graphKey = String(graphId ?? "")
        if (graphKey.length === 0
                || root.graphNodeLayoutOffsets[graphKey] === undefined)
            return
        const nextAll = Object.assign({}, root.graphNodeLayoutOffsets)
        delete nextAll[graphKey]
        root.graphNodeLayoutOffsets = nextAll
        root.graphLayoutRevision += 1
        root.persist()
    }

    function clearSemanticAnchor(): void {
        root.semanticAnchor = ""
        root.semanticAnchorNodeId = ""
        root.persist()
    }

    function bindSemanticAnchor(nodeId: string, anchor: string): bool {
        const nextNodeId = String(nodeId ?? "")
        const nextAnchor = String(anchor ?? "")
        if (nextNodeId.length === 0
                || nextAnchor.length === 0
                || nextNodeId !== root.selectedNodeId)
            return false
        root.semanticAnchor = nextAnchor
        root.semanticAnchorNodeId = nextNodeId
        root.persist()
        return true
    }

    function selectTarget(targetId: string, instanceId: string): void {
        if (!CodeWorkflowRuntime.descriptor(targetId))
            return
        root.selectedTargetId = targetId
        root.rememberTarget(targetId)
        root.selectedInstanceId = String(instanceId ?? "")
        const split = root.selectedInstanceId.lastIndexOf("@")
        if (split > 0)
            root.outputName = root.selectedInstanceId.slice(split + 1)

        if (CodeWorkflowIr.hasGraph(targetId)) {
            const changedSubflow = root.subflowTargetId !== targetId
            root.subflowTargetId = targetId
            const graph = CodeWorkflowIr.graphFor(targetId)
            root.selectedNodeId = graph.rootNodeId
                ?? graph.nodes?.[0]?.id ?? ""
            root.selectedEdgeId = ""
            root.selectedConnectTargetId = ""
            root.selectedSemanticAnchor = ""
            root.clearSemanticAnchor()
            // Selection changes inspector context, not the unified board viewport.
            // Keep pan/zoom while switching between unrelated components.
        }
        root.persist()
    }

    function selectNode(nodeId: string): void {
        if (!CodeWorkflowIr.nodeFor(root.subflowTargetId, nodeId))
            return
        const changed = root.selectedNodeId !== nodeId
        root.selectedNodeId = nodeId
        root.selectedEdgeId = ""
        root.selectedConnectTargetId = ""
        root.selectedSemanticAnchor = ""
        if (changed)
            root.clearSemanticAnchor()
        else
            root.persist()
    }

    function selectUnifiedNode(node): bool {
        const graphId = String(node?.graphId ?? "")
        const nodeId = String(node?.id ?? "")
        if (!CodeWorkflowIr.nodeFor(graphId, nodeId))
            return false
        root.subflowTargetId = graphId
        // The source graph and the runtime object are separate identities:
        // e.g. bar.media belongs to the Bar graph but inspects bar/media.
        const runtimeId = String(node.runtimeTargetId ?? "")
        if (runtimeId.length > 0
                && CodeWorkflowRuntime.descriptor(runtimeId)) {
            root.selectedTargetId = runtimeId
            root.rememberTarget(runtimeId)
            root.selectedInstanceId = root.outputName.length > 0
                ? runtimeId + "@" + root.outputName : ""
        }
        root.selectNode(nodeId)
        return true
    }

    function selectUnifiedEdge(edge): bool {
        const graphId = String(edge?.graphId ?? "")
        const edgeId = String(edge?.id ?? "")
        if (!CodeWorkflowIr.edgeFor(graphId, edgeId))
            return false
        root.subflowTargetId = graphId
        return root.selectEdge(edgeId)
    }

    function selectEdge(edgeId: string): bool {
        const nextEdgeId = String(edgeId ?? "")
        const edge = CodeWorkflowIr.edgeFor(
            root.subflowTargetId, nextEdgeId)
        if (!edge)
            return false

        const signalAction =
            CodeWorkflowIr.reviewedSignalActionTargetForEdge(
                root.subflowTargetId, nextEdgeId)
        if (signalAction !== null) {
            const actionNode = CodeWorkflowIr.nodeFor(
                root.subflowTargetId,
                String(signalAction.actionNodeId ?? ""))
            if (!actionNode || actionNode.kind !== "action")
                return false
            root.selectedEdgeId = edge.id
            root.selectedConnectTargetId = ""
            root.selectedSemanticAnchor = ""
            root.selectedNodeId = actionNode.id
            root.clearSemanticAnchor()
            root.persist()
            return true
        }

        const target = CodeWorkflowIr.nodeFor(
            root.subflowTargetId, String(edge.to ?? ""))
        if (!target)
            return false

        // Inspection and mutation eligibility are separate concerns. Every
        // source-backed IR edge may be selected for read-only inspection, while
        // previewable mutation edges keep their stricter binding invariant.
        if (edge.previewable === true && target.kind !== "binding")
            return false

        const changedNode = root.selectedNodeId !== target.id
        root.selectedEdgeId = edge.id
        root.selectedConnectTargetId = ""
        root.selectedSemanticAnchor = ""
        root.selectedNodeId = target.id
        if (changedNode)
            root.clearSemanticAnchor()
        else
            root.persist()
        return true
    }

    function selectSemantic(anchor: string): bool {
        const nextAnchor = String(anchor ?? "")
        if (nextAnchor.length === 0) {
            root.selectedSemanticAnchor = ""
            root.persist()
            return true
        }
        root.selectedSemanticAnchor = nextAnchor
        root.selectedEdgeId = ""
        root.selectedConnectTargetId = ""
        root.persist()
        return true
    }

    function selectConnectTarget(connectTargetId: string): bool {
        const target = CodeWorkflowIr.connectTargetFor(
            root.subflowTargetId, String(connectTargetId ?? ""))
        if (!target
                || target.previewable !== false
                || target.editable !== false
                || target.typeCompatibility !== "unknown-unresolved"
                || target.cycleStatus !== "unknown-incomplete-projection")
            return false

        const parentNode = CodeWorkflowIr.nodeFor(
            root.subflowTargetId,
            String(target.parentNodeId ?? ""))
        if (!parentNode)
            return false

        root.selectedConnectTargetId = String(target.id ?? "")
        root.selectedEdgeId = ""
        root.selectedSemanticAnchor = ""
        root.selectedNodeId = parentNode.id
        root.clearSemanticAnchor()
        root.persist()
        return true
    }

    function openSubflow(targetId: string): bool {
        if (!CodeWorkflowIr.hasGraph(targetId))
            return false

        root.subflowTargetId = targetId
        const graph = CodeWorkflowIr.graphFor(targetId)
        root.selectedNodeId = graph.rootNodeId
            ?? graph.nodes?.[0]?.id ?? ""
        root.selectedEdgeId = ""
        root.selectedConnectTargetId = ""
        root.selectedSemanticAnchor = ""
        root.clearSemanticAnchor()

        if (CodeWorkflowRuntime.descriptor(targetId)) {
            root.selectedTargetId = targetId
            root.selectedInstanceId = root.outputName.length > 0
                ? targetId + "@" + root.outputName
                : ""
        }

        // Subflow selection changes the inspector scope, not the canvas.
        root.persist()
        return true
    }

    function setOutputName(name: string): void {
        root.outputName = String(name ?? "")
        root.selectedInstanceId = root.outputName.length > 0
            ? root.selectedTargetId + "@" + root.outputName : ""
        root.persist()
    }

    function setViewportTransient(
        x: real, y: real, nextZoom: real
    ): void {
        root.viewportInitialized = true
        root.panX = Number(x)
        root.panY = Number(y)
        root.zoom = Math.max(root.minimumZoom, Math.min(
            root.maximumZoom, Number(nextZoom)))
    }

    function commitViewport(): void {
        root.persist()
    }

    function setViewport(x: real, y: real, nextZoom: real): void {
        root.setViewportTransient(x, y, nextZoom)
        root.commitViewport()
    }

    function resetViewport(): void {
        root.setViewport(32, 28, 1)
    }

    onSelectedTargetIdChanged: root.persist()
    onSelectedInstanceIdChanged: root.persist()
    onOutputNameChanged: root.persist()
    onSubflowTargetIdChanged: root.persist()
    onSelectedNodeIdChanged: root.persist()
    onSelectedEdgeIdChanged: root.persist()
    onSelectedConnectTargetIdChanged: root.persist()
    onSemanticAnchorChanged: root.persist()
    onSemanticAnchorNodeIdChanged: root.persist()
    onSourcePreviewVisibleChanged: root.persist()
    onTargetsPaneWidthChanged: root.persist()
    onInspectorPaneWidthChanged: root.persist()
    onTargetsPaneCollapsedChanged: root.persist()
    onInspectorPaneCollapsedChanged: root.persist()
    onSourcePreviewHeightChanged: root.persist()
    onMinimapEnabledChanged: root.persist()
    onPinnedTargetIdChanged: root.persist()
    onRecentTargetIdsChanged: root.persist()
    Component.onCompleted: root.restore()

    Connections {
        target: Persistent
        function onReadyChanged(): void {
            if (Persistent.ready)
                root.restore()
        }
    }

    Connections {
        target: CodeWorkflowIr
        function onReadyChanged(): void {
            if (CodeWorkflowIr.ready)
                root.restore()
        }
    }

    Connections {
        target: CodeWorkflowRuntime
        function onRevisionChanged(): void {
            if (!root._ready)
                root.restore()
        }
        function onRemoteErrorChanged(): void {
            if (!root._ready && CodeWorkflowRuntime.remoteError.length > 0)
                root.restore()
        }
    }
}
