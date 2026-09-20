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

    function hasGraph(targetId: string): bool {
        return !!root.document?.graphs?.[targetId]
    }

    function graphFor(targetId: string): var {
        return root.document?.graphs?.[targetId]
            ?? root.document?.graphs?.["bar"]
            ?? root.emptyGraph
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
