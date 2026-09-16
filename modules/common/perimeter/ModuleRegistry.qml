pragma Singleton

import QtQuick

QtObject {
    id: root

    // Core registration is metadata-only. Feature implementations register a
    // source URL when they are ready to be hosted; placement is never encoded here.
    // reservationKind describes compositor work-area semantics, not placement:
    // "bar" and "dock" can reserve their host edge, while "overlay" never does.
    readonly property var _builtinRegistry: ({
        "thinkfan": { moduleId: "thinkfan", preferredOrientation: "any", compact: true, expanded: true, reservationKind: "bar", source: "" },
        "system-monitor": { moduleId: "system-monitor", preferredOrientation: "any", compact: true, expanded: true, reservationKind: "bar", source: "" },
        "workspaces": { moduleId: "workspaces", preferredOrientation: "horizontal", compact: true, expanded: false, reservationKind: "bar", source: "" },
        "media": { moduleId: "media", preferredOrientation: "any", compact: true, expanded: true, reservationKind: "bar", source: "" },
        "weather": { moduleId: "weather", preferredOrientation: "any", compact: true, expanded: true, reservationKind: "bar", source: "" },
        "left-sidebar": { moduleId: "left-sidebar", preferredOrientation: "vertical", compact: true, expanded: true, reservationKind: "overlay", source: "" },
        "right-sidebar": { moduleId: "right-sidebar", preferredOrientation: "vertical", compact: true, expanded: true, reservationKind: "overlay", source: "" },
        "dock": { moduleId: "dock", preferredOrientation: "horizontal", compact: true, expanded: true, reservationKind: "dock", source: "" }
    })
    property var _registry: Object.assign({}, _builtinRegistry)

    signal moduleRegistered(string moduleId)
    signal moduleUnregistered(string moduleId)

    readonly property var moduleIds: Object.keys(_registry)

    function resolve(moduleId) {
        return root._registry[String(moduleId ?? "")] ?? null
    }

    function isRegistered(moduleId) {
        return root.resolve(moduleId) !== null
    }

    // Registration and resolution are intentionally distinct. Core can know a
    // module ID and its presentation metadata before Agent B supplies a concrete
    // QML source. PerimeterModuleHost should only instantiate resolvable modules.
    function isResolvable(moduleId) {
        const descriptor = root.resolve(moduleId)
        return descriptor !== null
            && String(descriptor?.source ?? "").trim().length > 0
    }

    function registerModule(moduleId, descriptor) {
        const id = String(moduleId ?? "").trim()
        if (!id)
            return false
        const current = root._registry[id] ?? ({})
        const next = Object.assign({}, root._registry)
        const merged = Object.assign({}, current, descriptor ?? ({}), {
            moduleId: id
        })
        const builtin = root._builtinRegistry[id] ?? null
        if (builtin) {
            // Feature registration may supply a source and extension fields, but
            // builtin presentation/reservation metadata remains core-owned. Keep
            // this generic so future builtin metadata keys are protected too.
            const immutableMetadata = Object.assign({}, builtin)
            delete immutableMetadata.source
            next[id] = Object.assign({}, merged, immutableMetadata, {
                moduleId: id
            })
        } else {
            next[id] = merged
        }
        root._registry = next
        root.moduleRegistered(id)
        return true
    }

    function unregisterModule(moduleId) {
        const id = String(moduleId ?? "").trim()
        if (!id || !root._registry[id])
            return false
        const next = Object.assign({}, root._registry)
        const builtin = root._builtinRegistry[id] ?? null
        if (builtin)
            next[id] = Object.assign({}, builtin)
        else
            delete next[id]
        root._registry = next
        root.moduleUnregistered(id)
        return true
    }

    // Readiness is a property of the rendered layout, not of the whole instance
    // catalog. Descriptors may intentionally exist unplaced so Settings can move
    // or stage modules without making an otherwise valid output fail readiness.
    function validateConfiguredModules(outputName, requireSources) {
        if (!PerimeterConfig.validate(outputName))
            return false

        const needSources = Boolean(requireSources ?? false)
        for (const slotId of PerimeterTopology.slotIds) {
            for (const instanceId of PerimeterConfig.slotInstanceIds(outputName, slotId)) {
                const instance = PerimeterConfig.instanceDescriptor(outputName, instanceId)
                if (!instance || !root.isRegistered(instance?.moduleId))
                    return false
                if (needSources && !root.isResolvable(instance?.moduleId))
                    return false
            }
        }
        return true
    }
}
