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
        if (!CodeWorkflowIr.hasGraph(root.subflowTargetId))
            root.subflowTargetId = "bar"
        if (!CodeWorkflowIr.nodeFor(root.subflowTargetId, root.selectedNodeId))
            root.selectedNodeId = CodeWorkflowIr.graphFor(
                root.subflowTargetId).rootNodeId ?? ""
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
        state.codeWorkflowPanX = root.panX
        state.codeWorkflowPanY = root.panY
        state.codeWorkflowZoom = root.zoom
        state.codeWorkflowSourcePreview = root.sourcePreviewVisible
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
            root.resetViewport()
        }
        root.persist()
    }

    function selectNode(nodeId: string): void {
        if (!CodeWorkflowIr.nodeFor(root.subflowTargetId, nodeId))
            return
        root.selectedNodeId = nodeId
        root.persist()
    }

    function openSubflow(targetId: string): bool {
        if (!CodeWorkflowIr.hasGraph(targetId))
            return false

        root.subflowTargetId = targetId
        const graph = CodeWorkflowIr.graphFor(targetId)
        root.selectedNodeId = graph.rootNodeId
            ?? graph.nodes?.[0]?.id ?? ""

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
