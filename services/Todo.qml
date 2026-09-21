pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import QtQuick

/**
 * Todo service facade.
 *
 * The internal JSON/TXT persistence implementation is isolated behind
 * InternalTodoBackend so the public service contract can later select an
 * Obsidian backend without duplicating TodoWidget/Dashboard integration.
 *
 * This commit intentionally keeps the internal backend as the only active
 * implementation. Public behavior remains identical to the previous service.
 */
Singleton {
    id: root

    InternalTodoBackend {
        id: internal
    }

    property alias filePath: internal.filePath
    property alias txtFilePath: internal.txtFilePath
    property alias list: internal.list
    property alias ready: internal.ready

    function addItem(item) {
        return internal.addItem(item)
    }

    function addTask(desc) {
        return internal.addTask(desc)
    }

    function markDone(index) {
        return internal.markDone(index)
    }

    function markUnfinished(index) {
        return internal.markUnfinished(index)
    }

    function deleteItem(index) {
        return internal.deleteItem(index)
    }

    function refresh() {
        internal.refresh()
    }
}
