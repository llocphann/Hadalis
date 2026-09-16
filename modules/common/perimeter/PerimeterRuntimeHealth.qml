pragma Singleton

import QtQuick

QtObject {
    id: root

    // Root-level handshake for the URL-loaded perimeter runtime. Module failures
    // are tracked separately below; this bit only proves that PerimeterRuntime.qml
    // instantiated far enough to complete its own bootstrap.
    property bool runtimeHostReady: false
    property var _moduleFailures: ({})
    readonly property var failureKeys: Object.keys(root._moduleFailures)

    function setRuntimeHostReady(ready: bool): void {
        root.runtimeHostReady = ready === true
    }

    function _key(outputName: string, instanceId: string): string {
        return JSON.stringify([
            String(outputName ?? ""),
            String(instanceId ?? "")
        ])
    }

    function reportModuleFailure(outputName: string, instanceId: string,
            moduleId: string, source: string, configRevision: int): void {
        const output = String(outputName ?? "")
        const instance = String(instanceId ?? "")
        const module = String(moduleId ?? "")
        const moduleSource = String(source ?? "")
        if (!output || !instance || !module || !moduleSource)
            return

        const key = root._key(output, instance)
        const current = root._moduleFailures[key] ?? null
        if (current !== null
                && current.moduleId === module
                && current.source === moduleSource
                && current.configRevision === configRevision)
            return

        const next = Object.assign({}, root._moduleFailures)
        next[key] = {
            outputName: output,
            instanceId: instance,
            moduleId: module,
            source: moduleSource,
            configRevision: configRevision
        }
        root._moduleFailures = next
    }

    function clearModuleFailure(outputName: string, instanceId: string,
            moduleId: string, source: string, configRevision: int): void {
        const key = root._key(outputName, instanceId)
        const current = root._moduleFailures[key] ?? null
        if (current === null
                || current.moduleId !== String(moduleId ?? "")
                || current.source !== String(source ?? "")
                || current.configRevision !== configRevision)
            return

        const next = Object.assign({}, root._moduleFailures)
        delete next[key]
        root._moduleFailures = next
    }

    function hasMatchingFailure(outputName: string, instanceId: string,
            moduleId: string, source: string, configRevision: int): bool {
        const current = root._moduleFailures[root._key(outputName, instanceId)] ?? null
        return current !== null
            && current.moduleId === String(moduleId ?? "")
            && current.source === String(source ?? "")
            && current.configRevision === configRevision
    }
}
