pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root

    // Canonical identity constructors shared by Workflow and future
    // Diagnostics telemetry. These objects intentionally carry IDs only;
    // presentation metadata remains owned by CodeWorkflowRuntime / IR.
    function targetRef(targetId: string): var {
        const id = String(targetId ?? "").trim()
        return id.length > 0
            ? ({ kind: "target", targetId: id })
            : null
    }

    function instanceRef(targetId: string, instanceId: string): var {
        const id = String(targetId ?? "").trim()
        const instance = String(instanceId ?? "").trim()
        return id.length > 0 && instance.length > 0
            ? ({ kind: "instance", targetId: id, instanceId: instance })
            : null
    }

    function graphNodeRef(graphId: string, nodeId: string): var {
        const graph = String(graphId ?? "").trim()
        const node = String(nodeId ?? "").trim()
        return graph.length > 0 && node.length > 0
            ? ({ kind: "graph-node", graphId: graph, nodeId: node })
            : null
    }

    function sourceRef(sourcePath: string, semanticAnchor: string): var {
        const path = String(sourcePath ?? "").trim()
        const anchor = String(semanticAnchor ?? "").trim()
        return path.length > 0 && anchor.length > 0
            ? ({
                kind: "source",
                sourcePath: path,
                semanticAnchor: anchor
            })
            : null
    }

    function isValid(ref): bool {
        if (!ref || typeof ref !== "object")
            return false
        switch (String(ref.kind ?? "")) {
        case "target":
            return String(ref.targetId ?? "").length > 0
        case "instance":
            return String(ref.targetId ?? "").length > 0
                && String(ref.instanceId ?? "").length > 0
        case "graph-node":
            return String(ref.graphId ?? "").length > 0
                && String(ref.nodeId ?? "").length > 0
        case "source":
            return String(ref.sourcePath ?? "").length > 0
                && String(ref.semanticAnchor ?? "").length > 0
        default:
            return false
        }
    }

    function key(ref): string {
        if (!root.isValid(ref))
            return ""
        switch (String(ref.kind)) {
        case "target":
            return "target|" + String(ref.targetId)
        case "instance":
            return "instance|" + String(ref.targetId)
                + "|" + String(ref.instanceId)
        case "graph-node":
            return "graph-node|" + String(ref.graphId)
                + "|" + String(ref.nodeId)
        case "source":
            return "source|" + String(ref.sourcePath)
                + "|" + String(ref.semanticAnchor)
        default:
            return ""
        }
    }

    function sanitize(ref): var {
        if (!root.isValid(ref))
            return null
        switch (String(ref.kind)) {
        case "target":
            return root.targetRef(ref.targetId)
        case "instance":
            return root.instanceRef(ref.targetId, ref.instanceId)
        case "graph-node":
            return root.graphNodeRef(ref.graphId, ref.nodeId)
        case "source":
            return root.sourceRef(ref.sourcePath, ref.semanticAnchor)
        default:
            return null
        }
    }
}
