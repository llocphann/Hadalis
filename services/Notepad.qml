pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import Quickshell
import Quickshell.Io
import QtQuick

/**
 * Multi-tab persistent notepad.
 * Stores tabs as JSON in notepad-tabs.json, migrates legacy notepad.txt.
 * Backward compat: `text` property reflects current tab content.
 */
Singleton {
    id: root

    readonly property string tabsFilePath: `${Directories.stateUserPath}/notepad-tabs.json`
    readonly property string legacyFilePath: Directories.notepadPath

    // Current tab state
    property int currentTab: 0
    property var tabs: [{ id: "bootstrap", title: "Note 1", text: "" }]
    property bool ready: false
    property int _tabIdCounter: 0
    property bool _normalizedTabsNeedSave: false
    // Convenience: current tab text (backward compat)
    readonly property string text: (tabs[currentTab]?.text) ?? ""

    function _allocateTabId() {
        root._tabIdCounter += 1
        return "tab-" + Date.now().toString(36)
            + "-" + root._tabIdCounter.toString(36)
    }

    function _makeTab(title, text) {
        return {
            id: root._allocateTabId(),
            title: String(title ?? ""),
            text: String(text ?? "")
        }
    }

    function _normalizeTabs(value) {
        if (!Array.isArray(value)) return []
        const normalized = []
        const seenIds = []
        root._normalizedTabsNeedSave = false
        for (let i = 0; i < value.length; i++) {
            const tab = value[i]
            if (!tab || typeof tab !== "object" || Array.isArray(tab))
                continue
            const rawId = String(tab.id ?? "")
            let id = rawId.trim()
            if (id !== rawId)
                root._normalizedTabsNeedSave = true
            if (!id || seenIds.includes(id)) {
                do {
                    id = root._allocateTabId()
                } while (seenIds.includes(id))
                root._normalizedTabsNeedSave = true
            }
            seenIds.push(id)
            normalized.push({
                id: id,
                title: String(tab.title ?? `Note ${normalized.length + 1}`),
                text: String(tab.text ?? "")
            })
        }
        return normalized
    }

    function indexForTabId(tabId) {
        const id = String(tabId ?? "")
        if (!id) return -1
        return tabs.findIndex(tab => String(tab?.id ?? "") === id)
    }

    function setTabTextById(tabId, newText) {
        return root.setTabText(root.indexForTabId(tabId), newText)
    }

    function setTabText(index, newText) {
        if (!root.ready || index < 0 || index >= tabs.length) return false
        const t = tabs.slice()
        t[index] = Object.assign({}, t[index], { text: String(newText ?? "") })
        tabs = t
        _save()
        return true
    }

    function setTextValue(newText) {
        return root.setTabText(currentTab, newText)
    }

    function setTabTitle(index, title) {
        if (!root.ready || index < 0 || index >= tabs.length) return false
        const t = tabs.slice()
        t[index] = Object.assign({}, t[index], { title: String(title ?? "") })
        tabs = t
        _save()
        return true
    }

    function addTab(title) {
        if (!root.ready) return false
        const t = tabs.slice()
        const requested = String(title ?? "").trim()
        const name = requested.length > 0 ? requested : `Note ${t.length + 1}`
        t.push(root._makeTab(name, ""))
        tabs = t
        currentTab = t.length - 1
        _save()
        return true
    }

    function removeTab(index) {
        if (!root.ready || index < 0 || index >= tabs.length) return false
        if (tabs.length <= 1) return false // Keep at least one tab

        const previousCurrent = currentTab
        const t = tabs.slice()
        t.splice(index, 1)
        tabs = t

        // Preserve the same logical active note when a tab before it is
        // removed. Removing the active tab selects the next note when possible,
        // otherwise the new last note.
        if (index < previousCurrent)
            currentTab = previousCurrent - 1
        else if (previousCurrent >= t.length)
            currentTab = t.length - 1
        else
            currentTab = previousCurrent

        _save()
        return true
    }

    function switchTab(index) {
        if (!root.ready || index < 0 || index >= tabs.length) return false
        currentTab = index
        _save()
        return true
    }

    // FileView fires onLoaded after our own setText() write. Keep at most one
    // self-write in flight so a later callback cannot fall through into the
    // disk parser while newer in-memory edits are waiting to be persisted.
    property bool _saving: false
    property bool _saveQueued: false
    // Fresh-start mkdir is asynchronous. While it is running, keep edits in
    // memory and persist the latest state once the directory is ready.
    property bool _storageInitializing: false

    function _save() {
        if (!root.ready || _storageInitializing)
            return false
        if (_saving) {
            _saveQueued = true
            return true
        }
        _saving = true
        tabsFileView.setText(JSON.stringify({ currentTab: currentTab, tabs: tabs }))
        return true
    }

    function refresh() {
        tabsFileView.reload()
    }

    Component.onCompleted: refresh()

    // Tabs JSON storage
    FileView {
        id: tabsFileView
        path: Qt.resolvedUrl(root.tabsFilePath)

        onLoaded: {
            if (root._saving) {
                root._saving = false
                if (root._saveQueued) {
                    root._saveQueued = false
                    Qt.callLater(() => root._save())
                }
                return
            }
            try {
                const data = JSON.parse(tabsFileView.text())
                const loadedTabs = root._normalizeTabs(data?.tabs)
                if (loadedTabs.length > 0) {
                    const requestedIndex = Number(data?.currentTab)
                    const index = Number.isInteger(requestedIndex) ? requestedIndex : 0
                    root.tabs = loadedTabs
                    root.currentTab = Math.max(0, Math.min(index, loadedTabs.length - 1))
                    root.ready = true
                    if (root._normalizedTabsNeedSave)
                        Qt.callLater(() => root._save())
                    return
                }
                // The tabs file exists, so legacy migration is no longer safe:
                // an old notepad.txt may be stale and would overwrite evidence
                // needed to recover the current multi-tab store. Fail closed.
                console.warn("[Notepad] Tabs file contains no valid tabs; preserving it")
            } catch (e) {
                console.warn("[Notepad] Invalid tabs file; preserving it:", e)
            }
        }

        onLoadFailed: (error) => {
            if (error === FileViewError.FileNotFound) {
                // Try migrating from legacy notepad.txt
                legacyFileView.path = Qt.resolvedUrl(root.legacyFilePath)
            } else {
                console.log("[Notepad] Error loading tabs file:", error)
            }
        }
    }

    // Legacy notepad.txt migration. No declarative `path`: if set eagerly the
    // FileView auto-loads on startup, races the tabs JSON load, and its onLoaded
    // unconditionally resets tabs to a single legacy note and saves — wiping every
    // extra tab on every restart. Only load it on demand when the tabs file is
    // genuinely missing/invalid (path assigned above).
    FileView {
        id: legacyFileView

        onLoaded: {
            const content = legacyFileView.text()
            root.tabs = [root._makeTab("Note 1", String(content ?? ""))]
            root.currentTab = 0
            root.ready = true
            root._save()
        }

        onLoadFailed: {
            // No legacy file either — fresh start. Serialize mkdir before the
            // first FileView write so the marker cannot race its parent directory.
            root.tabs = [root._makeTab("Note 1", "")]
            root.currentTab = 0
            root._storageInitializing = true
            if (!createStorageDirProc.running)
                createStorageDirProc.running = true
        }
    }

    Process {
        id: createStorageDirProc
        running: false
        property bool startObserved: false
        command: [
            "/usr/bin/mkdir",
            "-p",
            root.tabsFilePath.substring(0, root.tabsFilePath.lastIndexOf('/'))
        ]

        onRunningChanged: {
            if (createStorageDirProc.running) {
                createStorageDirProc.startObserved = false
                return
            }
            if (createStorageDirProc.startObserved)
                return

            root._storageInitializing = false
            root.ready = true
            console.warn("[Notepad] Failed to start state directory creation")
            root._save()
        }

        onStarted: createStorageDirProc.startObserved = true

        onExited: (exitCode, exitStatus) => {
            root._storageInitializing = false
            root.ready = true
            if (exitCode !== 0)
                console.warn("[Notepad] Failed to create state directory", exitCode, exitStatus)
            root._save()
        }
    }
}
