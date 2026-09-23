pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

Singleton {
    id: root

    // Runtime declarations are owned by the shell loaders that actually decide
    // whether a surface exists. This registry is the migration path away from
    // the temporary static catalog below; it deliberately records lifecycle
    // truth without forcing LazyLoader.item while asynchronous loading is active.
    property var declarations: ({})
    // Last observed loader lifecycle per declaration token. This is diagnostic
    // state only; it never activates a loader or dereferences loader.item.
    property var declarationStates: ({})
    property var staleDescriptors: ({})
    property int declarationSerial: 0
    property var remoteSnapshot: null
    property string remoteError: ""
    property double remoteUpdatedAtMs: 0
    property bool remoteRefreshing: false
    readonly property bool hasLocalDeclarations:
        Object.keys(root.declarations).length > 0

    function refreshRemoteSnapshot(): void {
        if (root.hasLocalDeclarations || remoteSnapshotProcess.running)
            return
        root.remoteRefreshing = true
        root.remoteError = ""
        remoteSnapshotProcess.running = true
    }

    function _kebabCase(value: string): string {
        return String(value ?? "")
            .replace(/([A-Z]+)([A-Z][a-z])/g, "$1-$2")
            .replace(/([a-z0-9])([A-Z])/g, "$1-$2")
            .replace(/[_\s]+/g, "-")
            .toLowerCase()
    }

    function targetIdForPanel(panelId: string): string {
        const id = String(panelId ?? "")
        if (id === "iiSidebarLeft")
            return "sidebar/left"
        if (id === "iiSidebarRight")
            return "sidebar/right"
        if (id === "iiOnScreenKeyboard")
            return "osk"
        if (id === "iiOnScreenDisplay")
            return "osd"
        if (id === "wOnScreenDisplay")
            return "waffle/osd"
        if (id.startsWith("ii"))
            return root._kebabCase(id.slice(2))
        if (id.startsWith("w"))
            return "waffle/" + root._kebabCase(id.slice(1))
        return root._kebabCase(id)
    }

    function labelForPanel(panelId: string): string {
        const id = String(panelId ?? "")
        const waffle = id.startsWith("w") && !id.startsWith("ii")
        const bare = id.startsWith("ii") ? id.slice(2)
            : waffle ? id.slice(1) : id
        const spaced = bare
            .replace(/([A-Z]+)([A-Z][a-z])/g, "$1 $2")
            .replace(/([a-z0-9])([A-Z])/g, "$1 $2")
            .trim()
        return waffle ? "Waffle " + spaced : spaced
    }

    function relativeSourcePath(rawSource): string {
        let source = String(rawSource ?? "")
        if (source.length === 0)
            return ""
        source = source.replace(/^file:\/\//, "")
        let shellRoot = String(Quickshell.shellPath(".") ?? "")
            .replace(/^file:\/\//, "")
            .replace(/\/$/, "")
        if (source.startsWith(shellRoot + "/"))
            return source.slice(shellRoot.length + 1)
        return source
    }

    function registerDeclaration(registration): string {
        if (!registration)
            return ""
        const token = root.epoch + ":declaration:" + (++root.declarationSerial)
        const next = Object.assign({}, root.declarations)
        next[token] = registration
        root.declarations = next
        const descriptor = registration?.descriptorSnapshot?.() ?? null
        const state = String(
            descriptor?.lifecycle ?? descriptor?.state ?? "")
        const nextStates = Object.assign({}, root.declarationStates)
        nextStates[token] = state
        root.declarationStates = nextStates
        const targetId = String(
            descriptor?.targetId
                ?? registration.targetId ?? registration.panelId ?? "")
        root._event("declared", targetId, token, targetId)
        return token
    }

    function _rememberStale(
        descriptor, token, instanceId, outputName
    ): void {
        if (!descriptor || String(descriptor.targetId ?? "").length === 0)
            return
        const staleToken = String(token ?? "")
        const key = staleToken.length > 0
            ? staleToken : String(descriptor.targetId)
        const next = Object.assign({}, root.staleDescriptors)
        next[key] = Object.assign({}, descriptor, {
            state: "stale",
            lifecycle: "stale/unloading",
            stateRank: 2,
            staleToken: staleToken,
            staleInstanceId: String(instanceId ?? ""),
            staleOutput: String(outputName ?? ""),
            expiresAtMs: Date.now() + 1500
        })
        root.staleDescriptors = next
        root.revision++
    }

    function _pruneStale(): void {
        const now = Date.now()
        const next = Object.assign({}, root.staleDescriptors)
        let changed = false
        for (const key of Object.keys(next)) {
            if (Number(next[key]?.expiresAtMs ?? 0) > now)
                continue
            delete next[key]
            changed = true
        }
        if (!changed)
            return
        root.staleDescriptors = next
        root.revision++
    }

    function unregisterDeclaration(
        token: string, registration
    ): void {
        if (String(token ?? "").length === 0
                || root.declarations[token] !== registration)
            return
        const descriptor = registration?.descriptorSnapshot?.() ?? null
        const targetId = String(descriptor?.targetId
            ?? registration?.targetId ?? "")
        const next = Object.assign({}, root.declarations)
        delete next[token]
        root.declarations = next
        const nextStates = Object.assign({}, root.declarationStates)
        delete nextStates[token]
        root.declarationStates = nextStates
        root._rememberStale(descriptor, token)
        root._event("declaration-stale", targetId, token, targetId)
    }

    function touchDeclaration(token: string): void {
        const tokenId = String(token ?? "")
        const registration = root.declarations[tokenId]
        if (tokenId.length === 0 || !registration)
            return

        const descriptor = registration?.descriptorSnapshot?.() ?? null
        const nextState = String(
            descriptor?.lifecycle ?? descriptor?.state ?? "")
        const previousState = String(root.declarationStates[tokenId] ?? "")
        if (nextState.length > 0 && nextState !== previousState) {
            const nextStates = Object.assign({}, root.declarationStates)
            nextStates[tokenId] = nextState
            root.declarationStates = nextStates
            const targetId = String(
                descriptor?.targetId ?? registration?.targetId ?? "")
            root._event(nextState, targetId, tokenId, targetId)
            return
        }
        root.revision++
    }

    function discoveredDescriptors(): var {
        const byTarget = ({})
        for (const token of Object.keys(root.declarations)) {
            const declaration = root.declarations[token]
            const descriptor = declaration?.descriptorSnapshot?.() ?? null
            if (!descriptor || String(descriptor.targetId ?? "").length === 0)
                continue
            const current = byTarget[descriptor.targetId]
            const nextRank = Number(descriptor.stateRank ?? 0)
            const currentRank = Number(current?.stateRank ?? -1)
            if (!current || nextRank > currentRank)
                byTarget[descriptor.targetId] = descriptor
        }
        for (const key of Object.keys(root.entries)) {
            const registration = root.entries[key]
            const descriptor = registration?.descriptorSnapshot?.() ?? null
            if (!descriptor || String(descriptor.targetId ?? "").length === 0)
                continue
            const current = byTarget[descriptor.targetId]
            const nextRank = Number(descriptor.stateRank ?? 0)
            const currentRank = Number(current?.stateRank ?? -1)
            if (!current || nextRank > currentRank)
                byTarget[descriptor.targetId] = descriptor
        }
        const now = Date.now()
        for (const key of Object.keys(root.staleDescriptors)) {
            const descriptor = root.staleDescriptors[key]
            if (!descriptor
                    || Number(descriptor.expiresAtMs ?? 0) <= now
                    || String(descriptor.targetId ?? "").length === 0)
                continue
            const current = byTarget[descriptor.targetId]
            const nextRank = Number(descriptor.stateRank ?? 0)
            const currentRank = Number(current?.stateRank ?? -1)
            if (!current || nextRank > currentRank)
                byTarget[descriptor.targetId] = descriptor
        }
        return Object.keys(byTarget)
            .map(key => byTarget[key])
            .sort((a, b) => String(a.label).localeCompare(String(b.label)))
    }

    readonly property var discoveredCatalog: {
        const dependency = root.revision
        if (dependency < 0)
            return []
        return root.discoveredDescriptors()
    }

    // Runtime inventory comes only from real loader declarations and live
    // registrations. Standalone Settings reads the same descriptors through IPC.
    readonly property var localCatalog: root.discoveredCatalog
    readonly property var activeCatalog: {
        const dependency = root.revision
        if (dependency < 0)
            return []
        if (!root.hasLocalDeclarations
                && Array.isArray(root.remoteSnapshot?.descriptors))
            return root.remoteSnapshot.descriptors
        return root.localCatalog
    }
    // Compatibility alias; there is no synthetic catalog behind this name.
    readonly property var catalog: root.activeCatalog

    function isActiveTarget(targetId: string): bool {
        return root.activeCatalog.some(item => item.targetId === targetId)
    }

    readonly property string epoch: Date.now().toString() + "-" + Math.random().toString(36).slice(2)
    property var entries: ({})
    // Last observed presentation lifecycle per live instance. Kept separate
    // from the QObject registration map so event dedupe stays primitive-only.
    property var entryStates: ({})
    property var events: []
    property int serial: 0
    property int revision: 0

    function descriptor(targetId: string): var {
        return root.activeCatalog.find(item => item.targetId === targetId) ?? null
    }

    function _event(
        kind: string, instanceId: string, token: string, targetId: string
    ): void {
        root.events = root.events.concat([{
            kind: kind,
            targetId: targetId,
            instanceId: instanceId,
            token: token,
            atMs: Date.now()
        }]).slice(-64)
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
        const descriptor = registration?.descriptorSnapshot?.() ?? null
        const nextStates = Object.assign({}, root.entryStates)
        nextStates[key] = String(
            descriptor?.lifecycle ?? descriptor?.state ?? "resident")
        root.entryStates = nextStates
        const token = root.epoch + ":" + (++root.serial)
        root._event(
            "resident", key, token,
            String(descriptor?.targetId ?? registration?.targetId ?? ""))
        return token
    }

    function detach(instanceId: string, registration, token: string): void {
        if (root.entries[instanceId] !== registration)
            return
        const descriptor = registration?.descriptorSnapshot?.() ?? null
        const outputName = String(registration?.outputName ?? "")
        const next = Object.assign({}, root.entries)
        delete next[instanceId]
        root.entries = next
        const nextStates = Object.assign({}, root.entryStates)
        delete nextStates[instanceId]
        root.entryStates = nextStates
        root._rememberStale(descriptor, token, instanceId, outputName)
        root._event(
            "stale/unloading", instanceId, token,
            String(descriptor?.targetId ?? registration?.targetId ?? ""))
    }

    function touchInstance(
        instanceId: string, registration, token: string
    ): void {
        const key = String(instanceId ?? "")
        if (key.length === 0 || root.entries[key] !== registration)
            return

        const descriptor = registration?.descriptorSnapshot?.() ?? null
        const nextState = String(
            descriptor?.lifecycle ?? descriptor?.state ?? "resident")
        const previousState = String(root.entryStates[key] ?? "")
        if (nextState.length > 0 && nextState !== previousState) {
            const nextStates = Object.assign({}, root.entryStates)
            nextStates[key] = nextState
            root.entryStates = nextStates
            const targetId = String(
                descriptor?.targetId ?? registration?.targetId ?? "")
            root._event(nextState, key, token, targetId)
            return
        }
        root.revision++
    }

    function localSnapshot(): var {
        const outputs = Quickshell.screens.map(screen => screen.name)
        const records = []

        for (const token of Object.keys(root.declarations)) {
            const declaration = root.declarations[token]
            const descriptor = declaration?.descriptorSnapshot?.() ?? null
            if (!descriptor || String(descriptor.targetId ?? "").length === 0)
                continue
            records.push({
                targetId: descriptor.targetId,
                instanceId: "",
                output: "",
                sourcePath: descriptor.sourcePath,
                depth: Number(descriptor.depth ?? 0),
                configured: descriptor.configured !== false,
                presented: descriptor.presented === true,
                state: String(descriptor.state ?? "unloaded"),
                lifecycle: String(
                    descriptor.lifecycle ?? descriptor.state ?? "unloaded"),
                runtimeToken: token,
                rect: null,
                values: null
            })
        }

        for (const key of Object.keys(root.entries)) {
            const registration = root.entries[key]
            const descriptor = registration?.descriptorSnapshot?.() ?? null
            if (!registration?.runtimeObject || !descriptor)
                continue
            records.push({
                targetId: descriptor.targetId,
                instanceId: key,
                output: String(registration.outputName ?? ""),
                sourcePath: descriptor.sourcePath,
                depth: Number(descriptor.depth ?? 0),
                configured: descriptor.configured !== false,
                presented: descriptor.presented !== false,
                state: "resident",
                lifecycle: String(descriptor.lifecycle ?? "visible"),
                runtimeToken: registration.token ?? null,
                rect: registration.rectSnapshot(),
                values: registration.safeValues()
            })
        }

        const now = Date.now()
        for (const key of Object.keys(root.staleDescriptors)) {
            const descriptor = root.staleDescriptors[key]
            if (!descriptor || Number(descriptor.expiresAtMs ?? 0) <= now)
                continue
            records.push({
                targetId: descriptor.targetId,
                instanceId: String(descriptor.staleInstanceId ?? ""),
                output: String(descriptor.staleOutput ?? ""),
                sourcePath: descriptor.sourcePath,
                depth: Number(descriptor.depth ?? 0),
                configured: descriptor.configured !== false,
                presented: false,
                state: "stale",
                lifecycle: "stale/unloading",
                runtimeToken: descriptor.staleToken ?? null,
                rect: null,
                values: null
            })
        }

        return {
            epoch: root.epoch,
            outputs: outputs,
            descriptors: root.discoveredCatalog,
            records: records,
            events: root.events
        }
    }

    function snapshot(): var {
        if (!root.hasLocalDeclarations && root.remoteSnapshot !== null)
            return root.remoteSnapshot
        return root.localSnapshot()
    }

    Timer {
        id: stalePruneTimer
        interval: 500
        repeat: true
        running: Object.keys(root.staleDescriptors).length > 0
        onTriggered: root._pruneStale()
    }

    Process {
        id: remoteSnapshotProcess
        running: false
        command: [
            Quickshell.shellPath("scripts/inir"),
            "ipc", "codeWorkflowRuntime", "snapshot"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                const payload = String(text ?? "").trim()
                if (payload.length === 0)
                    return
                try {
                    const next = JSON.parse(payload)
                    if (!Array.isArray(next?.records)
                            || !Array.isArray(next?.descriptors))
                        throw new Error("invalid runtime snapshot payload")
                    root.remoteSnapshot = next
                    root.remoteUpdatedAtMs = Date.now()
                    root.remoteError = ""
                    root.revision++
                } catch (error) {
                    root.remoteError =
                        "Runtime snapshot decode failed: " + String(error)
                }
            }
        }

        stderr: StdioCollector {
            id: remoteSnapshotErrorCollector
        }

        onExited: (exitCode, exitStatus) => {
            root.remoteRefreshing = false
            if (exitCode !== 0 && root.remoteError.length === 0) {
                const detail = String(remoteSnapshotErrorCollector.text ?? "").trim()
                root.remoteError = detail.length > 0
                    ? detail : "Runtime snapshot IPC exited with " + exitCode
            }
        }
    }

    Timer {
        interval: 1200
        repeat: true
        running: !root.hasLocalDeclarations
        onTriggered: root.refreshRemoteSnapshot()
    }

    onHasLocalDeclarationsChanged: {
        if (root.hasLocalDeclarations) {
            root.remoteSnapshot = null
            root.remoteError = ""
        } else {
            Qt.callLater(root.refreshRemoteSnapshot)
        }
    }

    Component.onCompleted: Qt.callLater(root.refreshRemoteSnapshot)

    function hit(output: string, x: real, y: real): string {
        const candidates = root.snapshot().records.filter(record => {
            const rect = record.rect
            return record.output === output
                && record.state === "resident"
                && rect?.eligible
                && x >= rect.x && y >= rect.y
                && x < rect.x + rect.width
                && y < rect.y + rect.height
        })

        candidates.sort((a, b) =>
            b.depth - a.depth
            || a.rect.width * a.rect.height
                - b.rect.width * b.rect.height)

        return candidates.length > 0 ? candidates[0].instanceId : ""
    }
}
