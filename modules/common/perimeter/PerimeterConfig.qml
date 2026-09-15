pragma Singleton

import QtQuick
import qs.modules.common

QtObject {
    id: root

    readonly property int schemaVersion: 1

    // Persistence remains owned by Config. Until Config exposes a schema-backed
    // perimeter node, this preset is the architecture default and configured
    // data is consumed when that node exists.
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
    readonly property int configuredSchemaVersion:
        Number(configured?.schemaVersion ?? schemaVersion)
    readonly property bool schemaSupported:
        configured === null || configuredSchemaVersion === schemaVersion

    function _array(value, fallback) {
        return Array.isArray(value) ? value.slice() : fallback.slice()
    }

    // Accept both the original map representation and a JsonAdapter-friendly
    // list representation:
    //   [{ slotId: "top.start", instanceIds: ["..."] }, ...]
    function _slotValue(container, slotId) {
        const id = String(slotId ?? "")
        if (Array.isArray(container)) {
            const entry = container.find(candidate =>
                String(candidate?.slotId ?? candidate?.slot ?? "") === id)
            return entry?.instanceIds ?? entry?.instances
        }
        return container?.[id]
    }

    // Likewise, per-output overrides may be an object keyed by output name or
    // a list suitable for JsonAdapter list<var> persistence.
    function _outputConfig(outputName) {
        const name = String(outputName ?? "")
        const outputs = root.configured?.outputs ?? root.defaultPreset.outputs
        if (Array.isArray(outputs)) {
            return outputs.find(entry =>
                String(entry?.outputName ?? entry?.output ?? "") === name) ?? null
        }
        return outputs?.[name] ?? null
    }

    function _sharedInstances() {
        const shared = root.configured?.instances
        return Array.isArray(shared) ? shared : root.defaultPreset.instances
    }

    function _outputInstances(outputName) {
        const output = root._outputConfig(outputName)
        return Array.isArray(output?.instances) ? output.instances : []
    }

    function _descriptorLayerValid(descriptors) {
        const seen = ({})
        for (const descriptor of descriptors) {
            const instanceId = String(descriptor?.instanceId ?? "")
            const moduleId = String(descriptor?.moduleId ?? "")
            if (!instanceId || !moduleId || seen[instanceId])
                return false
            seen[instanceId] = true
        }
        return true
    }

    function slotInstanceIds(outputName, slotId) {
        const id = String(slotId ?? "")
        if (!PerimeterTopology.isValidSlot(id))
            return []

        const fallback = root.defaultPreset.defaultSlots[id] ?? []
        const sharedSlots = root.configured?.defaultSlots ?? root.configured?.slots
        const shared = root._slotValue(sharedSlots, id)
        const output = root._outputConfig(outputName)
        const override = root._slotValue(output?.slots, id)
        return root._array(override, root._array(shared, fallback))
    }

    function instancesForOutput(outputName) {
        const base = root._sharedInstances()
        const additions = root._outputInstances(outputName)
        const byId = ({})

        // Output descriptors intentionally override a shared descriptor with the
        // same instance ID. Duplicates within either layer are rejected by validate().
        for (const descriptor of base.concat(additions)) {
            const id = String(descriptor?.instanceId ?? "")
            if (id.length > 0)
                byId[id] = descriptor
        }
        return Object.keys(byId).map(id => byId[id])
    }

    function instanceDescriptor(outputName, instanceId) {
        const id = String(instanceId ?? "")
        return root.instancesForOutput(outputName).find(entry =>
            String(entry?.instanceId ?? "") === id) ?? null
    }

    function placementForInstance(outputName, instanceId) {
        const id = String(instanceId ?? "")
        if (!id)
            return ""
        for (const slotId of PerimeterTopology.slotIds) {
            if (root.slotInstanceIds(outputName, slotId).some(candidate =>
                String(candidate ?? "") === id))
                return slotId
        }
        return ""
    }

    function validate(outputName) {
        if (!root.schemaSupported)
            return false

        const base = root._sharedInstances()
        const additions = root._outputInstances(outputName)
        if (!root._descriptorLayerValid(base) || !root._descriptorLayerValid(additions))
            return false

        const instances = root.instancesForOutput(outputName)
        const known = ({})
        for (const descriptor of instances) {
            const instanceId = String(descriptor?.instanceId ?? "")
            const moduleId = String(descriptor?.moduleId ?? "")
            if (!instanceId || !moduleId)
                return false
            known[instanceId] = true
        }

        // One instance ID represents one concrete module instance. Reusing the
        // same ID in multiple slots is ambiguous; multiple copies must use
        // distinct instance IDs even when their moduleId is identical.
        const placed = ({})
        for (const slotId of PerimeterTopology.slotIds) {
            for (const rawInstanceId of root.slotInstanceIds(outputName, slotId)) {
                const instanceId = String(rawInstanceId ?? "")
                if (!instanceId || !known[instanceId] || placed[instanceId])
                    return false
                placed[instanceId] = slotId
            }
        }
        return true
    }
}
