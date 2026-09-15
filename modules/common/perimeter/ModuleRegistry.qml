pragma Singleton

import QtQuick

QtObject {
    id: root

    // Core registration is metadata-only. Feature implementations register a
    // source URL when they are ready to be hosted; placement is never encoded here.
    property var _registry: ({
        "thinkfan": { moduleId: "thinkfan", preferredOrientation: "any", compact: true, expanded: true, source: "" },
        "system-monitor": { moduleId: "system-monitor", preferredOrientation: "any", compact: true, expanded: true, source: "" },
        "workspaces": { moduleId: "workspaces", preferredOrientation: "horizontal", compact: true, expanded: false, source: "" },
        "media": { moduleId: "media", preferredOrientation: "any", compact: true, expanded: true, source: "" },
        "weather": { moduleId: "weather", preferredOrientation: "any", compact: true, expanded: true, source: "" },
        "left-sidebar": { moduleId: "left-sidebar", preferredOrientation: "vertical", compact: true, expanded: true, source: "" },
        "right-sidebar": { moduleId: "right-sidebar", preferredOrientation: "vertical", compact: true, expanded: true, source: "" },
        "dock": { moduleId: "dock", preferredOrientation: "horizontal", compact: true, expanded: true, source: "" }
    })

    signal moduleRegistered(string moduleId)
    signal moduleUnregistered(string moduleId)

    readonly property var moduleIds: Object.keys(_registry)

    function resolve(moduleId) {
        return root._registry[String(moduleId ?? "")] ?? null
    }

    function isRegistered(moduleId) {
        return root.resolve(moduleId) !== null
    }

    function registerModule(moduleId, descriptor) {
        const id = String(moduleId ?? "").trim()
        if (!id)
            return false
        const current = root._registry[id] ?? ({})
        const next = Object.assign({}, root._registry)
        next[id] = Object.assign({}, current, descriptor ?? ({}), { moduleId: id })
        root._registry = next
        root.moduleRegistered(id)
        return true
    }

    function unregisterModule(moduleId) {
        const id = String(moduleId ?? "").trim()
        if (!id || !root._registry[id])
            return false
        const next = Object.assign({}, root._registry)
        delete next[id]
        root._registry = next
        root.moduleUnregistered(id)
        return true
    }

    function validateConfiguredModules(outputName) {
        for (const instance of PerimeterConfig.instancesForOutput(outputName)) {
            if (!root.isRegistered(instance?.moduleId))
                return false
        }
        return true
    }
}
