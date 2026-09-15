pragma Singleton

import QtQuick
import qs.modules.common

QtObject {
    id: root

    readonly property int schemaVersion: 1

    // Persistence is owned by Config; this preset supplies architecture defaults
    // when the typed perimeter node is empty or has no explicit overrides.
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

    // Use Config's revision-aware accessor instead of binding directly to an
    // optional QObject property. This keeps the contract reactive.
    readonly property var configured: Config.getNestedValue("perimeter", null)
    readonly property bool persistenceReady: configured !== null
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

    function _slotContainerValid(container) {
        if (container === undefined || container === null)
            return true

        if (Array.isArray(container)) {
            const seen = ({})
            for (const entry of container) {
                const slotId = String(entry?.slotId ?? entry?.slot ?? "")
                const instanceIds = entry?.instanceIds ?? entry?.instances
                if (!PerimeterTopology.isValidSlot(slotId)
                        || seen[slotId] || !Array.isArray(instanceIds))
                    return false
                seen[slotId] = true
            }
            return true
        }

        if (typeof container !== "object")
            return false
        for (const slotId of Object.keys(container)) {
            if (!PerimeterTopology.isValidSlot(slotId)
                    || !Array.isArray(container[slotId]))
                return false
        }
        return true
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
        // A typed JsonAdapter schema can safely default instances to []. Treat
        // that empty schema value as "use the architecture preset"; modules are
        // removed from the layout by empty slot arrays, not by deleting the
        // descriptor catalog.
        return Array.isArray(shared) && shared.length > 0
            ? shared : root.defaultPreset.instances
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

    function _outputEntryValid(output) {
        if (!output || typeof output !== "object")
            return false
        if (output.instances !== undefined) {
            if (!Array.isArray(output.instances)
                    || !root._descriptorLayerValid(output.instances))
                return false
        }
        return root._slotContainerValid(output.slots)
    }

    function _outputsContainerValid(outputs) {
        if (outputs === undefined || outputs === null)
            return true

        if (Array.isArray(outputs)) {
            const seen = ({})
            for (const output of outputs) {
                const name = String(output?.outputName ?? output?.output ?? "")
                if (!name || seen[name] || !root._outputEntryValid(output))
                    return false
                seen[name] = true
            }
            return true
        }

        if (typeof outputs !== "object")
            return false
        for (const name of Object.keys(outputs)) {
            if (!name || !root._outputEntryValid(outputs[name]))
                return false
        }
        return true
    }

    function _configuredShapeValid() {
        if (root.configured === null)
            return true
        if (typeof root.configured !== "object" || Array.isArray(root.configured))
            return false

        const instances = root.configured?.instances
        if (instances !== undefined && !Array.isArray(instances))
            return false
        if (Array.isArray(instances) && instances.length > 0
                && !root._descriptorLayerValid(instances))
            return false

        const sharedSlots = root.configured?.defaultSlots ?? root.configured?.slots
        if (!root._slotContainerValid(sharedSlots))
            return false
        return root._outputsContainerValid(root.configured?.outputs)
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
        if (!root.schemaSupported || !root._configuredShapeValid())
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
