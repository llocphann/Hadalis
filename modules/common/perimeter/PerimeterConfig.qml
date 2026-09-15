pragma Singleton

import QtQuick
import qs.modules.common

QtObject {
    id: root

    readonly property int schemaVersion: 1

    // Persistence remains owned by Config. When Config.options.perimeter is not
    // present yet, this preset provides the architecture default without creating
    // a second config file or persistence path.
    readonly property var defaultPreset: ({
        schemaVersion: 1,
        instances: [
            { instanceId: "thinkfan-main", moduleId: "thinkfan" },
            { instanceId: "system-monitor-main", moduleId: "system-monitor" },
            { instanceId: "workspaces-main", moduleId: "workspaces" },
            { instanceId: "media-main", moduleId: "media" },
            { instanceId: "weather-main", moduleId: "weather" },
            { instanceId: "left-sidebar-main", moduleId: "left-sidebar" },
            { instanceId: "right-sidebar-main", moduleId: "right-sidebar" },
            { instanceId: "dock-main", moduleId: "dock" }
        ],
        defaultSlots: {
            "top.start": ["thinkfan-main", "system-monitor-main"],
            "top.center": ["workspaces-main", "media-main", "weather-main"],
            "top.end": [],
            "left.center": ["left-sidebar-main"],
            "right.center": ["right-sidebar-main"],
            "bottom.start": [],
            "bottom.center": ["dock-main"],
            "bottom.end": []
        },
        outputs: {}
    })

    readonly property var configured: Config.options?.perimeter ?? null

    function _array(value, fallback) {
        return Array.isArray(value) ? value.slice() : fallback.slice()
    }

    function _outputConfig(outputName) {
        const outputs = root.configured?.outputs ?? root.defaultPreset.outputs
        return outputs?.[String(outputName ?? "")] ?? null
    }

    function slotInstanceIds(outputName, slotId) {
        const id = String(slotId ?? "")
        if (!PerimeterTopology.isValidSlot(id))
            return []
        const fallback = root.defaultPreset.defaultSlots[id] ?? []
        const shared = root.configured?.defaultSlots?.[id]
        const output = root._outputConfig(outputName)
        const override = output?.slots?.[id]
        return root._array(override, root._array(shared, fallback))
    }

    function instancesForOutput(outputName) {
        const shared = root.configured?.instances
        const base = Array.isArray(shared) ? shared : root.defaultPreset.instances
        const output = root._outputConfig(outputName)
        const additions = Array.isArray(output?.instances) ? output.instances : []
        const byId = ({})
        for (const descriptor of base.concat(additions)) {
            const id = String(descriptor?.instanceId ?? "")
            if (id.length > 0)
                byId[id] = descriptor
        }
        return Object.keys(byId).map(id => byId[id])
    }

    function instanceDescriptor(outputName, instanceId) {
        const id = String(instanceId ?? "")
        return root.instancesForOutput(outputName).find(entry => entry.instanceId === id) ?? null
    }

    function validate(outputName) {
        const instances = root.instancesForOutput(outputName)
        const known = ({})
        for (const descriptor of instances) {
            const instanceId = String(descriptor?.instanceId ?? "")
            const moduleId = String(descriptor?.moduleId ?? "")
            if (!instanceId || !moduleId || known[instanceId])
                return false
            known[instanceId] = true
        }
        for (const slotId of PerimeterTopology.slotIds) {
            for (const instanceId of root.slotInstanceIds(outputName, slotId)) {
                if (!known[instanceId])
                    return false
            }
        }
        return true
    }
}
