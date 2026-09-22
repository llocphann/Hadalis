pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var document: ({
        schema: 0,
        mode: "unavailable",
        editable: false,
        sourceAnchorMode: "none",
        graphs: ({})
    })
    property bool ready: false
    property string error: ""

    readonly property var emptyGraph: ({
        title: "Workflow unavailable",
        rootNodeId: "",
        sourcePath: "",
        nodes: [],
        edges: [],
        connectTargets: []
    })

    function sourceGraphFor(targetId: string): var {
        const descriptor = CodeWorkflowRuntime.descriptor(targetId)
        if (!descriptor)
            return root.emptyGraph
        const nodeId = String(targetId ?? "") + ".component"
        return {
            title: String(descriptor.label ?? targetId),
            rootNodeId: nodeId,
            sourcePath: String(descriptor.sourcePath ?? ""),
            nodes: [{
                id: nodeId,
                kind: String(descriptor.kind ?? "component"),
                title: String(descriptor.label ?? targetId),
                description: "Source-backed shell component",
                sourcePath: String(descriptor.sourcePath ?? ""),
                sourceNeedle: "",
                runtimeTargetId: String(targetId ?? ""),
                subflowTargetId: String(targetId ?? ""),
                x: 80,
                y: 80,
                editable: false
            }],
            edges: [],
            connectTargets: [],
            signalActionTargets: []
        }
    }

    function hasGraph(targetId: string): bool {
        return !!root.document?.graphs?.[targetId]
            || CodeWorkflowRuntime.descriptor(targetId) !== null
    }

    function graphFor(targetId: string): var {
        return root.document?.graphs?.[targetId]
            ?? root.sourceGraphFor(targetId)
    }

    function nodeFor(targetId: string, nodeId: string): var {
        const graph = root.graphFor(targetId)
        return graph.nodes?.find(node => node.id === nodeId) ?? null
    }

    function edgeFor(targetId: string, edgeId: string): var {
        const graph = root.graphFor(targetId)
        return graph.edges?.find(edge => edge.id === edgeId) ?? null
    }

    function previewableDataEdgesFor(targetId: string): var {
        const graph = root.graphFor(targetId)
        return (graph.edges ?? []).filter(edge =>
            edge.kind === "data"
            && edge.previewable === true
            && edge.previewTransform === "direct-binding-retarget")
    }

    function connectTargetsFor(targetId: string): var {
        return root.graphFor(targetId)?.connectTargets ?? []
    }

    function connectTargetFor(targetId: string, connectTargetId: string): var {
        return root.connectTargetsFor(targetId)
            .find(target => target.id === connectTargetId) ?? null
    }

    function signalActionTargetsFor(targetId: string): var {
        return root.graphFor(targetId)?.signalActionTargets ?? []
    }

    function signalActionTargetFor(
        targetId: string,
        signalActionTargetId: string
    ): var {
        return root.signalActionTargetsFor(targetId)
            .find(target => target.id === signalActionTargetId) ?? null
    }

    function reviewedSignalActionTargetForEdge(
        targetId: string,
        edgeId: string
    ): var {
        if (String(targetId ?? "") !== "bar/media")
            return null
        const edge = root.edgeFor(targetId, edgeId)
        if (!edge
                || String(edge.signalActionTargetId ?? "")
                    !== "media.signal.doubleClickToggle")
            return null
        const target = root.signalActionTargetFor(
            targetId, String(edge.signalActionTargetId ?? ""))
        if (!target
                || target.previewable !== false
                || target.editable !== false
                || String(target.eventNodeId ?? "") !== String(edge.from ?? "")
                || String(target.actionNodeId ?? "") !== String(edge.to ?? ""))
            return null
        return target
    }

    function reviewedSignalActionTargetForNode(
        targetId: string,
        nodeId: string
    ): var {
        if (String(targetId ?? "") !== "bar/media")
            return null
        const target = root.signalActionTargetFor(
            targetId, "media.signal.doubleClickToggle")
        if (!target)
            return null
        const nextNodeId = String(nodeId ?? "")
        return nextNodeId === String(target.eventNodeId ?? "")
                || nextNodeId === String(target.actionNodeId ?? "")
            ? target : null
    }

    FileView {
        id: manifestFile
        path: Quickshell.shellPath("defaults/code-workflow-ir.json")
        blockLoading: true
        printErrors: false

        onLoaded: {
            try {
                const parsed = JSON.parse(manifestFile.text())
                if (Number(parsed?.schema ?? 0) !== 1
                        || parsed?.mode !== "reviewed-source-projection"
                        || !parsed?.graphs)
                    throw new Error("unsupported Code Workflow IR schema")
                root.document = parsed
                root.error = ""
                root.ready = true
            } catch (e) {
                root.error = String(e)
                root.ready = false
            }
        }

        onLoadFailed: error => {
            root.error = String(error)
            root.ready = false
        }
    }
}
