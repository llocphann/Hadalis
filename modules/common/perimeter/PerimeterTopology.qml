pragma Singleton

import QtQuick

QtObject {
    id: root

    readonly property var slotIds: [
        "top.start", "top.center", "top.end",
        "left.center", "right.center",
        "bottom.start", "bottom.center", "bottom.end"
    ]
    readonly property var edges: ["top", "bottom", "left", "right"]

    function isValidSlot(slotId) {
        return root.slotIds.includes(String(slotId ?? ""))
    }

    function edgeForSlot(slotId) {
        const id = String(slotId ?? "")
        return root.isValidSlot(id) ? id.split(".")[0] : ""
    }

    function alignmentForSlot(slotId) {
        const id = String(slotId ?? "")
        return root.isValidSlot(id) ? id.split(".")[1] : ""
    }

    function orientationForEdge(edge) {
        const value = String(edge ?? "")
        if (value === "top" || value === "bottom")
            return "horizontal"
        if (value === "left" || value === "right")
            return "vertical"
        return ""
    }

    function inwardDirectionForEdge(edge) {
        switch (String(edge ?? "")) {
        case "top": return "down"
        case "bottom": return "up"
        case "left": return "right"
        case "right": return "left"
        default: return ""
        }
    }

    function describe(outputName, slotId) {
        const edge = root.edgeForSlot(slotId)
        return {
            outputName: String(outputName ?? ""),
            slotId: String(slotId ?? ""),
            edge: edge,
            alignment: root.alignmentForSlot(slotId),
            orientation: root.orientationForEdge(edge),
            inwardDirection: root.inwardDirectionForEdge(edge)
        }
    }
}
