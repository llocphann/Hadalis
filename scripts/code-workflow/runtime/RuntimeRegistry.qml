pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: registry
    // Probe-only registry. Never enumerates arbitrary QObject properties/children.
    readonly property var catalog: [
        { targetId: "bar", sourcePath: "modules/bar/BarContent.qml", depth: 0 },
        { targetId: "bar/media", sourcePath: "modules/bar/Media.qml", depth: 1 },
        { targetId: "bar/clock", sourcePath: "modules/bar/ClockWidget.qml", depth: 1 },
        { targetId: "bar/resources", sourcePath: "modules/bar/Resources.qml", depth: 1 }
    ]
    readonly property string epoch: Date.now().toString() + "-" + Math.random().toString(36).slice(2)
    property var entries: ({})
    property var events: []
    property int serial: 0
    property int revision: 0
    property int mediaActions: 0
    property bool pickHold: false
    property var heldOutputs: []
    property string selectedInstanceId: ""
    property string selectedTargetId: ""
    property var viewport: ({ x: 31, y: -17, zoom: 1.25, subflow: "bar" })

    function event(kind, instanceId, token) {
        events = events.concat([{kind: kind, instanceId: instanceId, token: token}]).slice(-64)
        revision++
    }
    function attach(probe) {
        const key = probe.instanceId
        if (!key || !probe.runtimeObject) return ""
        if (entries[key] && entries[key] !== probe) throw new Error("duplicate semantic instance: " + key)
        entries[key] = probe
        const token = epoch + ":" + (++serial)
        event("resident", key, token)
        return token
    }
    function detach(key, probe, token) {
        if (entries[key] !== probe) return
        delete entries[key]
        event("stale/unloading", key, token)
    }
    function descriptor(targetId) {
        return catalog.find(d => d.targetId === targetId) ?? null
    }
    function select(instanceId) {
        const split = instanceId.lastIndexOf("@")
        const targetId = instanceId.slice(0, split)
        if (split < 1 || !descriptor(targetId)) return false
        selectedInstanceId = instanceId
        selectedTargetId = targetId
        return true
    }
    function snapshot() {
        const names = Quickshell.screens.map(s => s.name)
        const records = []
        for (const output of names) {
            for (const d of catalog) {
                const key = d.targetId + "@" + output
                const p = entries[key]
                records.push({targetId: d.targetId, instanceId: key, output: output,
                    sourcePath: d.sourcePath, depth: d.depth,
                    state: p && p.runtimeObject ? "resident" : "unloaded",
                    runtimeToken: p?.token ?? null,
                    objectIdentity: p?.runtimeObject ? String(p.runtimeObject) : null,
                    rect: p ? p.rectSnapshot() : null,
                    values: p ? p.safeValues() : null})
            }
        }
        const selected = records.find(r => r.instanceId === selectedInstanceId)
        return {epoch: epoch, outputs: names, records: records, events: events,
            selectedInstanceId: selectedInstanceId, selectedTargetId: selectedTargetId,
            selectionState: selected ? selected.state : (selectedInstanceId ? "stale/output-removed" : "none"),
            viewport: viewport, pickHold: pickHold, heldOutputs: heldOutputs}
    }
    function hit(output, x, y) {
        const candidates = snapshot().records.filter(r => {
            const g = r.rect
            return r.output === output && r.state === "resident" && g && g.eligible
                && x >= g.x && y >= g.y && x < g.x + g.width && y < g.y + g.height
        })
        candidates.sort((a,b) => b.depth - a.depth
            || a.rect.width * a.rect.height - b.rect.width * b.rect.height)
        return candidates.length ? candidates[0].instanceId : ""
    }
}
