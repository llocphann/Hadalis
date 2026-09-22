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

    // A presentation-only board. Every link comes from the reviewed source
    // manifest; unrelated runtime declarations remain independent nodes.
    // Loader state is read from the registry, never inferred from a drawing,
    // and discovery never touches LazyLoader.item or activates any Loader.
    function unifiedGraphFor(showInternals: bool): var {
        const nodes = []
        const edges = []
        const groups = []
        const represented = ({})
        const layouts = [
            { id: "bar", x: 60, y: 82, width: 970, height: 1650 },
            { id: "bar/media", x: 1160, y: 82, width: 910, height: 610 },
            { id: "bar/clock", x: 1160, y: 752, width: 910, height: 550 },
            { id: "bar/resources", x: 1160, y: 1362, width: 910, height: 550 }
        ]
        const reviewed = root.document?.graphs ?? ({})
        for (const layout of layouts) {
            const graph = reviewed[layout.id]
            if (!graph)
                continue
            groups.push({
                id: layout.id,
                title: String(graph.title ?? layout.id) + " · reviewed source",
                x: layout.x - 24, y: layout.y - 36,
                width: layout.width, height: layout.height
            })
            for (const node of (graph.nodes ?? [])) {
                const nodeId = String(node.id ?? "")
                if (nodeId.length === 0)
                    continue
                nodes.push(Object.assign({}, node, {
                    graphId: layout.id,
                    x: layout.x + Number(node.x ?? 0),
                    y: layout.y + Number(node.y ?? 0)
                }))
                if (String(node.runtimeTargetId ?? "").length > 0)
                    represented[String(node.runtimeTargetId)] = true
            }
            for (const edge of (graph.edges ?? []))
                edges.push(Object.assign({}, edge, { graphId: layout.id }))
        }

        // Every currently discovered target gets a place even without a
        // verified relationship to another target. Internal Settings pages
        // remain behind Show internals, matching the Targets pane.
        const byFamily = ({})
        const catalog = CodeWorkflowRuntime.activeCatalog
        for (const descriptor of catalog) {
            const id = String(descriptor?.targetId ?? "")
            if (!id || represented[id] || (!showInternals && descriptor.internal === true))
                continue
            const family = (descriptor.internal === true ? "internal/" : "")
                + String(descriptor.family ?? "other")
            if (!byFamily[family])
                byFamily[family] = []
            byFamily[family].push(descriptor)
        }

        let nextY = 2080
        const columns = 6
        const pitchX = 232
        const pitchY = 124
        for (const family of Object.keys(byFamily).sort()) {
            const descriptors = byFamily[family].sort((a, b) =>
                String(a.label ?? a.targetId).localeCompare(
                    String(b.label ?? b.targetId)))
            const rows = Math.ceil(descriptors.length / columns)
            groups.push({
                id: "runtime/" + family,
                title: "Runtime · " + family + " · declaration state",
                x: 36, y: nextY - 36,
                width: columns * pitchX + 8,
                height: rows * pitchY + 60
            })
            for (let index = 0; index < descriptors.length; ++index) {
                const descriptor = descriptors[index]
                const targetId = String(descriptor.targetId)
                nodes.push({
                    id: targetId + ".component",
                    graphId: targetId,
                    runtimeTargetId: targetId,
                    subflowTargetId: targetId,
                    kind: String(descriptor.kind ?? "component"),
                    title: String(descriptor.label ?? targetId),
                    description: String(descriptor.lifecycle
                        ?? descriptor.state ?? "unloaded")
                        + " · runtime declaration",
                    sourcePath: String(descriptor.sourcePath ?? ""),
                    sourceNeedle: "",
                    runtimeState: String(descriptor.state ?? "unloaded"),
                    x: 58 + (index % columns) * pitchX,
                    y: nextY + Math.floor(index / columns) * pitchY,
                    editable: false
                })
            }
            nextY += rows * pitchY + 112
        }
        return {
            title: "Shell components · shared canvas",
            rootNodeId: nodes[0]?.id ?? "",
            nodes: nodes,
            edges: edges,
            groups: groups,
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
