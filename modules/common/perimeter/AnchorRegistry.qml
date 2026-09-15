pragma Singleton
import QtQuick
QtObject {
    id: root
    property var records: ({})
    property double _nextPublisherGeneration: 0
    signal changed(string key, var record)
    signal removed(string key)
    function surfaceName(value) { const name = String(value ?? "default"); return name.length > 0 ? name : "default" }
    function keyFor(outputName, instanceId, surfaceName) { return JSON.stringify([String(outputName ?? ""), String(instanceId ?? ""), root.surfaceName(surfaceName)]) }
    function numberFinite(value) { return Number.isFinite(Number(value)) }
    function rectHasArea(rect) {
        return rect
            && root.numberFinite(rect.x)
            && root.numberFinite(rect.y)
            && root.numberFinite(rect.width)
            && root.numberFinite(rect.height)
            && rect.width > 0
            && rect.height > 0
    }
    function allocatePublisherGeneration() {
        root._nextPublisherGeneration += 1
        return root._nextPublisherGeneration
    }
    function publish(record) {
        const outputName = String(record?.outputName ?? "")
        const instanceId = String(record?.instanceId ?? "")
        const moduleId = String(record?.moduleId ?? "")
        const slotId = String(record?.slotId ?? "")
        const surfaceName = root.surfaceName(record?.surfaceName)
        const coordinateSpace = String(record?.coordinateSpace ?? "")
        const publisherGeneration = Number(record?.publisherGeneration ?? 0)
        if (!record || !outputName || !instanceId || !moduleId || !PerimeterTopology.isValidSlot(slotId) || !root.rectHasArea(record.rect) || coordinateSpace !== "output-local" || !root.numberFinite(publisherGeneration) || publisherGeneration < 0) return false
        const key = root.keyFor(outputName, instanceId, surfaceName)
        const existing = root.records[key] ?? null
        const existingGeneration = Number(existing?.publisherGeneration ?? 0)
        if (existing && root.numberFinite(existingGeneration)
                && existingGeneration > publisherGeneration)
            return false
        const next = Object.assign({}, root.records)
        next[key] = Object.assign({}, record, { outputName: outputName, instanceId: instanceId, moduleId: moduleId, slotId: slotId, surfaceName: surfaceName, edge: PerimeterTopology.edgeForSlot(slotId), alignment: PerimeterTopology.alignmentForSlot(slotId), coordinateSpace: "output-local", publisherGeneration: publisherGeneration })
        root.records = next
        root.changed(key, next[key])
        return true
    }
    function lookup(outputName, instanceId, surfaceName) { return root.records[root.keyFor(outputName, instanceId, surfaceName)] || null }
    function unregister(outputName, instanceId, surfaceName, publisherGeneration) {
        const key = root.keyFor(outputName, instanceId, surfaceName)
        const current = root.records[key] ?? null
        if (!current) return false
        if (publisherGeneration !== undefined && publisherGeneration !== null) {
            const expectedGeneration = Number(publisherGeneration)
            if (!root.numberFinite(expectedGeneration)
                    || Number(current?.publisherGeneration ?? 0) !== expectedGeneration)
                return false
        }
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
