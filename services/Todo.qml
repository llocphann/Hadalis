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

    readonly property var list: root.useObsidian ? obsidian.list : internal.list
    readonly property bool ready: root.useObsidian ? obsidian.ready : internal.ready
    readonly property bool busy: root.useObsidian ? obsidian.busy : false
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
        active: root.useObsidian
        vaultPath: String(Config.options?.todo?.obsidian?.vaultPath ?? "")
        notePath: String(Config.options?.todo?.obsidian?.notePath ?? "Hadalis/Todo.md")
        preferTasksPlugin: Config.options?.todo?.obsidian?.preferTasksPlugin ?? true
        allowBasicOfflineMutation:
            Config.options?.todo?.obsidian?.allowBasicOfflineMutation ?? true
    }

    function _itemAt(index): var {
        if (!Number.isInteger(index) || index < 0 || index >= root.list.length)
            return null
        return root.list[index]
    }

    function initializeSection() {
        if (!root.useObsidian)
            return false
        return obsidian.initializeSection()
    }

    function migrateInternalToObsidian() {
        if (!root.useObsidian)
            return false
        return obsidian.migrateInternal(internal.filePath)
    }

    function addItem(item) {
        if (!root.useObsidian)
            return internal.addItem(item)
        const content = String(item?.content ?? item?.description ?? "")
        return obsidian.addTask(content)
    }

    function addTask(desc) {
        if (!root.useObsidian)
            return internal.addTask(desc)
        return obsidian.addTask(String(desc ?? ""))
    }

    function toggleTask(taskId) {
        if (!root.useObsidian) {
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
        if (!root.useObsidian)
            return internal.markDone(index)
        const item = root._itemAt(index)
        if (!item)
            return false
        if (item.done === true)
            return true
        return obsidian.toggleTask(String(item.id ?? ""))
    }

    function markUnfinished(index) {
        if (!root.useObsidian)
            return internal.markUnfinished(index)
        const item = root._itemAt(index)
        if (!item)
            return false
        if (item.done !== true)
            return true
        return obsidian.toggleTask(String(item.id ?? ""))
    }

    function deleteItem(index) {
        if (!root.useObsidian)
            return internal.deleteItem(index)
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

    function openSource(taskId) {
        if (!root.useObsidian) {
            Quickshell.execDetached(["xdg-open", internal.txtFilePath])
            return true
        }
        if (!obsidian.noteFullPath || obsidian.noteFullPath.length === 0)
            return false

        // User-triggered navigation is allowed to focus/open Obsidian.
        const uri = "obsidian://open?path=" + encodeURIComponent(obsidian.noteFullPath)
        Quickshell.execDetached(["xdg-open", uri])
        return true
    }
}
