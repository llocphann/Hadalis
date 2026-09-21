pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.modules.common

/**
 * Todo service facade.
 *
 * Existing installs remain on InternalTodoBackend because the append-only
 * config default is "internal". Obsidian becomes canonical only after the
 * backend value is explicitly changed by a setup/migration flow (or by an
 * advanced user editing config directly).
 */
Singleton {
    id: root

    readonly property string requestedBackend:
        String(Config.options?.todo?.backend ?? "internal")
    readonly property bool useObsidian: root.requestedBackend === "obsidian"
    readonly property string backend: root.useObsidian ? "obsidian" : "internal"

    // Setup is deliberately separate from canonical ownership. While this is
    // true the Obsidian backend may scan/initialize/preview, but public Todo
    // consumers continue to see the internal backend until activation commits.
    property bool _obsidianSetupActive: false
    property bool _activateAfterMigration: false
    property bool _migrationInFlight: false
    readonly property bool obsidianSetupActive: root._obsidianSetupActive
    readonly property bool obsidianConfigured: obsidian.configured
    readonly property bool obsidianReady: obsidian.ready
    readonly property bool obsidianBusy: obsidian.busy
    readonly property string obsidianErrorCode: obsidian.errorCode
    readonly property string obsidianErrorMessage: obsidian.errorMessage
    readonly property var obsidianCapabilities: obsidian.capabilities
    readonly property var obsidianMigrationPreview: obsidian.migrationPreview
    readonly property var obsidianList: obsidian.list
    readonly property string obsidianNoteFullPath: obsidian.noteFullPath
    readonly property bool internalPersistenceBusy: internal.persistenceBusy

    readonly property var list: root.useObsidian ? obsidian.list : internal.list
    readonly property bool ready: root.useObsidian ? obsidian.ready : internal.ready
    readonly property bool busy: root.useObsidian ? obsidian.busy : root._migrationInFlight
    readonly property string errorMessage: root.useObsidian ? obsidian.errorMessage : ""
    readonly property string errorCode: root.useObsidian ? obsidian.errorCode : ""
    readonly property var capabilities: root.useObsidian
        ? obsidian.capabilities
        : ({
            backend: "internal",
            noteReadable: true,
            noteWritable: true,
            richMutationAvailable: false,
            lastError: ""
        })
    readonly property string sourceLabel:
        root.useObsidian ? "Obsidian · " + String(Config.options?.todo?.obsidian?.notePath ?? "") : "Hadalis"
    readonly property int internalItemCount: internal.list.length

    // Compatibility paths remain the internal store paths. New UI must use
    // openSource() instead of assuming Todo.txtFilePath is canonical.
    property alias filePath: internal.filePath
    property alias txtFilePath: internal.txtFilePath

    InternalTodoBackend {
        id: internal
    }

    ObsidianTodoBackend {
        id: obsidian
        active: root.useObsidian || root._obsidianSetupActive
        vaultPath: String(Config.options?.todo?.obsidian?.vaultPath ?? "")
        notePath: String(Config.options?.todo?.obsidian?.notePath ?? "Hadalis/Todo.md")
        preferTasksPlugin: Config.options?.todo?.obsidian?.preferTasksPlugin ?? true
        allowBasicOfflineMutation:
            Config.options?.todo?.obsidian?.allowBasicOfflineMutation ?? true
    }

    Connections {
        target: obsidian

        function onMigrationFinished(success, payload): void {
            root._migrationInFlight = false
            if (!success)
                root._activateAfterMigration = false
        }

        function onMigrationCommitted(payload): void {
            root._migrationInFlight = false
            if (!root._activateAfterMigration)
                return
            root._activateAfterMigration = false

            // The migration helper has already re-scanned the canonical note
            // and ObsidianTodoBackend applied that fresh payload before this
            // signal is emitted. Only now may ownership move to Obsidian.
            Config.setNestedValue("todo.backend", "obsidian")
            root._obsidianSetupActive = false
        }
    }

    function _itemAt(index): var {
        if (!Number.isInteger(index) || index < 0 || index >= root.list.length)
            return null
        return root.list[index]
    }

    function beginObsidianSetup(): bool {
        if (root.useObsidian)
            return true
        root._activateAfterMigration = false
        root._obsidianSetupActive = true
        Qt.callLater(() => obsidian.reload())
        return true
    }

    function cancelObsidianSetup(): void {
        if (root.useObsidian || root._migrationInFlight)
            return
        root._activateAfterMigration = false
        root._obsidianSetupActive = false
    }

    function refreshObsidianSetup(): bool {
        if (!root.useObsidian && !root._obsidianSetupActive)
            return false
        obsidian.reload()
        return true
    }

    function initializeSection() {
        if (!root.useObsidian && !root._obsidianSetupActive)
            return false
        return obsidian.initializeSection()
    }

    function previewInternalToObsidian(): bool {
        if ((!root.useObsidian && !root._obsidianSetupActive)
                || !internal.ready
                || internal.persistenceBusy)
            return false
        return obsidian.previewInternal(internal.filePath)
    }

    function migrateInternalToObsidian(expectedInternalSha) {
        if ((!root.useObsidian && !root._obsidianSetupActive)
                || !internal.ready
                || internal.persistenceBusy
                || root._migrationInFlight)
            return false

        const staging = !root.useObsidian
        root._activateAfterMigration = staging
        const started = obsidian.migrateInternal(
            internal.filePath,
            String(expectedInternalSha ?? "")
        )
        if (started)
            root._migrationInFlight = staging
        else
            root._activateAfterMigration = false
        return started
    }

    function activateObsidian(): bool {
        if (root.useObsidian)
            return true
        if (!root._obsidianSetupActive || !obsidian.ready || obsidian.busy)
            return false

        Config.setNestedValue("todo.backend", "obsidian")
        root._activateAfterMigration = false
        root._obsidianSetupActive = false
        return true
    }

    function reactivateInternal(): bool {
        if (root._migrationInFlight)
            return false
        root._activateAfterMigration = false
        root._obsidianSetupActive = false
        Config.setNestedValue("todo.backend", "internal")
        return true
    }


    function addItem(item) {
        if (!root.useObsidian) {
            if (root._migrationInFlight)
                return false
            return internal.addItem(item)
        }
        const content = String(item?.content ?? item?.description ?? "")
        return obsidian.addTask(content)
    }

    function addTask(desc) {
        if (!root.useObsidian) {
            if (root._migrationInFlight)
                return false
            return internal.addTask(desc)
        }
        return obsidian.addTask(String(desc ?? ""))
    }

    function toggleTask(taskId) {
        if (!root.useObsidian) {
            if (root._migrationInFlight)
                return false
            const id = String(taskId ?? "")
            for (let i = 0; i < internal.list.length; ++i) {
                if (String(internal.list[i]?.id ?? "") === id) {
                    if (internal.list[i]?.done)
                        return internal.markUnfinished(i)
                    return internal.markDone(i)
                }
            }
            return false
        }
        return obsidian.toggleTask(String(taskId ?? ""))
    }

    function deleteTask(taskId) {
        if (!root.useObsidian) {
            if (root._migrationInFlight)
                return false
            const id = String(taskId ?? "")
            for (let i = 0; i < internal.list.length; ++i) {
                if (String(internal.list[i]?.id ?? "") === id)
                    return internal.deleteItem(i)
            }
            return false
        }
        return obsidian.deleteTask(String(taskId ?? ""))
    }

    // Compatibility wrappers for the existing TodoWidget/Dashboard delegates.
    // They resolve the current item first so Obsidian never mutates by index.
    function markDone(index) {
        if (!root.useObsidian) {
            if (root._migrationInFlight)
                return false
            return internal.markDone(index)
        }
        const item = root._itemAt(index)
        if (!item)
            return false
        if (item.done === true)
            return true
        return obsidian.toggleTask(String(item.id ?? ""))
    }

    function markUnfinished(index) {
        if (!root.useObsidian) {
            if (root._migrationInFlight)
                return false
            return internal.markUnfinished(index)
        }
        const item = root._itemAt(index)
        if (!item)
            return false
        if (item.done !== true)
            return true
        return obsidian.toggleTask(String(item.id ?? ""))
    }

    function deleteItem(index) {
        if (!root.useObsidian) {
            if (root._migrationInFlight)
                return false
            return internal.deleteItem(index)
        }
        const item = root._itemAt(index)
        if (!item)
            return false
        return obsidian.deleteTask(String(item.id ?? ""))
    }

    function refresh() {
        if (root.useObsidian)
            obsidian.reload()
        else
            internal.refresh()
    }

    function reload() {
        root.refresh()
    }

    function openObsidianSource(): bool {
        if ((!root.useObsidian && !root._obsidianSetupActive)
                || !obsidian.noteFullPath
                || obsidian.noteFullPath.length === 0)
            return false
        const uri = "obsidian://open?path=" + encodeURIComponent(obsidian.noteFullPath)
        Quickshell.execDetached(["xdg-open", uri])
        return true
    }

    function openSource(taskId) {
        if (!root.useObsidian) {
            Quickshell.execDetached(["xdg-open", internal.txtFilePath])
            return true
        }
        return root.openObsidianSource()
    }

    onUseObsidianChanged: {
        if (root.useObsidian) {
            root._migrationInFlight = false
            root._activateAfterMigration = false
            root._obsidianSetupActive = false
        }
    }
}
