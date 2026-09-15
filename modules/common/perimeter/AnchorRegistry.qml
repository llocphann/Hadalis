pragma Singleton
import QtQuick
QtObject {
    id: root
    property var records: ({})
    signal changed(string key, var record)
    signal removed(string key)
    function keyFor(outputName, instanceId, surfaceName) { return String(outputName) + "::" + String(instanceId) + "::" + String(surfaceName || "default") }
    function rectHasArea(rect) { return rect && rect.width > 0 && rect.height > 0 }
    function publish(record) {
        const coordinateSpace = String(record?.coordinateSpace ?? "")
        if (!record || !record.outputName || !record.instanceId || !record.moduleId || !PerimeterTopology.isValidSlot(record.slotId) || !root.rectHasArea(record.rect) || coordinateSpace !== "output-local") return false
        const key = root.keyFor(record.outputName, record.instanceId, record.surfaceName)
        const next = Object.assign({}, root.records)
        next[key] = Object.assign({}, record, { edge: PerimeterTopology.edgeForSlot(record.slotId), alignment: PerimeterTopology.alignmentForSlot(record.slotId), coordinateSpace: "output-local" })
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
        const prefix = String(outputName) + "::" + String(instanceId) + "::"
        const next = Object.assign({}, root.records)
        const removedKeys = []
        for (const key of Object.keys(next)) if (key.startsWith(prefix)) { delete next[key]; removedKeys.push(key) }
        if (removedKeys.length === 0) return false
        root.records = next
        for (const key of removedKeys) root.removed(key)
        return true
    }
    function forOutput(outputName) { return Object.values(root.records).filter(record => record.outputName === String(outputName)) }
}
