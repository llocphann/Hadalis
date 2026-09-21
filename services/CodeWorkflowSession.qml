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
    property real zoom: 1
    property bool sourcePreviewVisible: true
    property bool _restoring: false
    property bool _ready: false

    function _state(): var {
        return Persistent.states?.settings ?? null
    }

    function restore(): void {
        if (!Persistent.ready || !CodeWorkflowIr.ready)
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
        if (!restoredEdge
                || (restoredEdge.previewable !== true
                    && restoredSignalAction === null)) {
            root.selectedEdgeId = ""
        } else if (restoredSignalAction !== null) {
            const actionNode = CodeWorkflowIr.nodeFor(
                root.subflowTargetId,
                String(restoredSignalAction.actionNodeId ?? ""))
            if (actionNode)
                root.selectedNodeId = actionNode.id
            else
                root.selectedEdgeId = ""
        } else if (CodeWorkflowIr.nodeFor(
                root.subflowTargetId, restoredEdge.to)) {
            root.selectedNodeId = restoredEdge.to
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
        root.panX = Number(state.codeWorkflowPanX ?? 32)
        root.panY = Number(state.codeWorkflowPanY ?? 28)
        root.zoom = Math.max(0.35, Math.min(2.5, Number(state.codeWorkflowZoom ?? 1)))
        root.sourcePreviewVisible = state.codeWorkflowSourcePreview !== false
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
        root.selectedInstanceId = String(instanceId ?? "")
        const split = root.selectedInstanceId.lastIndexOf("@")
        if (split > 0)
            root.outputName = root.selectedInstanceId.slice(split + 1)

        if (CodeWorkflowIr.hasGraph(targetId)) {
            root.subflowTargetId = targetId
            const graph = CodeWorkflowIr.graphFor(targetId)
            root.selectedNodeId = graph.rootNodeId
                ?? graph.nodes?.[0]?.id ?? ""
            root.selectedEdgeId = ""
            root.selectedConnectTargetId = ""
            root.selectedSemanticAnchor = ""
            root.clearSemanticAnchor()
            root.resetViewport()
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

        if (edge.previewable !== true)
            return false
        const target = CodeWorkflowIr.nodeFor(
            root.subflowTargetId, String(edge.to ?? ""))
        if (!target || target.kind !== "binding")
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

        root.resetViewport()
        root.persist()
        return true
    }

    function setOutputName(name: string): void {
        root.outputName = String(name ?? "")
        root.selectedInstanceId = root.outputName.length > 0
            ? root.selectedTargetId + "@" + root.outputName : ""
        root.persist()
    }

    function setViewport(x: real, y: real, nextZoom: real): void {
        root.panX = Number(x)
        root.panY = Number(y)
        root.zoom = Math.max(0.35, Math.min(2.5, Number(nextZoom)))
        root.persist()
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
}
