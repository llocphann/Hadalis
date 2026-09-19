pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property var catalog: [
        { targetId: "bar", label: "Bar", icon: "toolbar", kind: "component", parentId: "", depth: 0, sourcePath: "modules/bar/BarContent.qml" },
        { targetId: "bar/media", label: "Media", icon: "music_note", kind: "component", parentId: "bar", depth: 1, sourcePath: "modules/bar/Media.qml" },
        { targetId: "bar/clock", label: "Clock", icon: "schedule", kind: "component", parentId: "bar", depth: 1, sourcePath: "modules/bar/ClockWidget.qml" },
        { targetId: "bar/resources", label: "Resources", icon: "memory", kind: "component", parentId: "bar", depth: 1, sourcePath: "modules/bar/Resources.qml" }
    ]

    readonly property string epoch: Date.now().toString() + "-" + Math.random().toString(36).slice(2)
    property var entries: ({})
    property var events: []
    property int serial: 0
    property int revision: 0

    function descriptor(targetId: string): var {
        return root.catalog.find(item => item.targetId === targetId) ?? null
    }

    function _event(kind: string, instanceId: string, token: string): void {
        root.events = root.events.concat([{ kind: kind, instanceId: instanceId, token: token }]).slice(-64)
        root.revision++
    }

    function attach(registration): string {
        const key = String(registration?.instanceId ?? "")
        if (key.length === 0 || !registration?.runtimeObject)
            return ""
        const current = root.entries[key]
        if (current && current !== registration)
            throw new Error("duplicate Code Workflow runtime instance: " + key)

        const next = Object.assign({}, root.entries)
        next[key] = registration
        root.entries = next
        const token = root.epoch + ":" + (++root.serial)
        root._event("resident", key, token)
        return token
    }

    function detach(instanceId: string, registration, token: string): void {
        if (root.entries[instanceId] !== registration)
            return
        const next = Object.assign({}, root.entries)
        delete next[instanceId]
        root.entries = next
        root._event("stale/unloading", instanceId, token)
    }

    function snapshot(): var {
        const outputs = Quickshell.screens.map(screen => screen.name)
        const records = []

        if (outputs.length === 0) {
            for (const descriptor of root.catalog) {
                records.push({
                    targetId: descriptor.targetId, instanceId: "", output: "",
                    sourcePath: descriptor.sourcePath, depth: descriptor.depth,
                    state: "unloaded", runtimeToken: null, rect: null, values: null
                })
            }
        } else {
            for (const output of outputs) {
                for (const descriptor of root.catalog) {
                    const key = descriptor.targetId + "@" + output
                    const registration = root.entries[key]
                    records.push({
                        targetId: descriptor.targetId,
                        instanceId: key,
                        output: output,
                        sourcePath: descriptor.sourcePath,
                        depth: descriptor.depth,
                        state: registration?.runtimeObject ? "resident" : "unloaded",
                        runtimeToken: registration?.token ?? null,
                        rect: registration ? registration.rectSnapshot() : null,
                        values: registration ? registration.safeValues() : null
                    })
                }
            }
        }
        return { epoch: root.epoch, outputs: outputs, records: records, events: root.events }
    }
}
