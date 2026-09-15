pragma Singleton
import QtQuick
QtObject {
    id: root
    property var records: ({})
    signal changed(string key, var record)
    signal removed(string key)
    function surfaceName(value) { const name = String(value ?? "default"); return name.length > 0 ? name : "default" }
    function keyFor(outputName, instanceId, surfaceName) { return JSON.stringify([String(outputName ?? ""), String(instanceId ?? ""), root.surfaceName(surfaceName)]) }
    function rectHasArea(rect) { return rect && rect.width > 0 && rect.height > 0 }
    function publish(record) {
        const outputName = String(record?.outputName ?? "")
        const instanceId = String(record?.instanceId ?? "")
        const moduleId = String(record?.moduleId ?? "")
        const slotId = String(record?.slotId ?? "")
        const surfaceName = root.surfaceName(record?.surfaceName)
        const coordinateSpace = String(record?.coordinateSpace ?? "")
        if (!record || !outputName || !instanceId || !moduleId || !PerimeterTopology.isValidSlot(slotId) || !root.rectHasArea(record.rect) || coordinateSpace !== "output-local") return false
        const key = root.keyFor(outputName, instanceId, surfaceName)
        const next = Object.assign({}, root.records)
        next[key] = Object.assign({}, record, { outputName: outputName, instanceId: instanceId, moduleId: moduleId, slotId: slotId, surfaceName: surfaceName, edge: PerimeterTopology.edgeForSlot(slotId), alignment: PerimeterTopology.alignmentForSlot(slotId), coordinateSpace: "output-local" })
        root.records = next
        root.changed(key, next[key])
        return true
    }
    function lookup(outputName, instanceId, surfaceName) { return root.records[root.keyFor(outputName, instanceId, surfaceName)] || null }
    function unregister(outputName, instanceId, surfaceName) {
        const key = root.keyFor(outputName, instanceId, surfaceName)
        if (!root.records[key]) return false
        const next = Object.assign({}, root.records)
        delete next[key]
        root.records = next
        root.removed(key)
        return true
    }
    function unregisterInstance(outputName, instanceId) {
        const output = String(outputName ?? "")
        const instance = String(instanceId ?? "")
        const next = Object.assign({}, root.records)
        const removedKeys = []
        for (const key of Object.keys(next)) {
            const record = next[key]
            if (String(record?.outputName ?? "") === output && String(record?.instanceId ?? "") === instance) {
                delete next[key]
                removedKeys.push(key)
            }
        }
        if (removedKeys.length === 0) return false
        root.records = next
        for (const key of removedKeys) root.removed(key)
        return true
    }
    function forOutput(outputName) { const output = String(outputName ?? ""); return Object.values(root.records).filter(record => record.outputName === output) }
}
