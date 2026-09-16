pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import Quickshell;
import Quickshell.Io;
import QtQuick;

/**
 * Simple to-do list manager with two-way text file sync.
 *
 * Backend: todo.json (JSON array of {content, done} objects)
 * Mirror:  todo.txt  (human-editable markdown-checkbox format)
 *
 * todo.txt format:
 *   - [ ] Undone task
 *   - [x] Done task
 *   # Comment (ignored)
 *   Plain text (treated as undone task)
 *
 * Sync model:
 *   UI action  -> update list -> write json + txt
 *   txt edited -> parse       -> update list -> write json (skip txt to avoid loop)
 *
 * Implementation note:
 *   FileView.setText() caches content internally; subsequent reload()+text()
 *   returns the cached buffer, NOT fresh disk content.  To read the actual
 *   file after an external edit we run `cat` via Process + StdioCollector,
 *   which always reads from disk.
 */
Singleton {
    id: root

    function _log(...args): void {
        if (Quickshell.env("QS_DEBUG") === "1") console.log(...args);
    }

    property string filePath: Directories.todoPath
    property string txtFilePath: Directories.todoTxtPath
    property var list: []

    // Guard flag: when true, skip writing txt back (because we're
    // processing a txt change and the file is already up-to-date)
    property bool _suppressTxtWrite: false

    // Startup guard: ignore txt onFileChanged until initial write settles.
    // Without this, the watcher can catch a truncated/empty intermediate state
    // from the initial setText() and destroy the list.
    property bool _startupLock: true

    // Fresh-start directory creation is asynchronous. Keep UI edits in memory
    // until storage is ready, then persist the latest list once.
    property bool _storageInitializing: false

    // FileView emits onLoaded after setText(). Serialize canonical JSON writes
    // so a stale self-write callback cannot rehydrate an older list while a
    // newer UI/external-text edit is waiting to be persisted.
    property bool _jsonSaving: false
    property bool _jsonSaveQueued: false

    // --- Public API ---

    function _normalizeList(value) {
        if (!Array.isArray(value)) return []
        const normalized = []
        for (let i = 0; i < value.length; i++) {
            const item = value[i]
            if (!item || typeof item !== "object" || Array.isArray(item))
                continue
            normalized.push({
                "content": String(item.content ?? ""),
                "done": item.done === true
            })
        }
        return normalized
    }

    function addItem(item) {
        const normalized = root._normalizeList([item])
        if (normalized.length === 0) return
        list.push(normalized[0])
        root.list = list.slice(0)
        _persistAll()
    }

    function addTask(desc) {
        addItem({ "content": desc, "done": false })
    }

    function markDone(index) {
        if (index >= 0 && index < list.length) {
            list[index].done = true
            root.list = list.slice(0)
            _persistAll()
        }
    }

    function markUnfinished(index) {
        if (index >= 0 && index < list.length) {
            list[index].done = false
            root.list = list.slice(0)
            _persistAll()
        }
    }

    function deleteItem(index) {
        if (index >= 0 && index < list.length) {
            list.splice(index, 1)
            root.list = list.slice(0)
            _persistAll()
        }
    }

    function refresh() {
        todoFileView.reload()
    }

    // --- Persistence helpers ---

    function _saveJson() {
        if (root._storageInitializing)
            return
        if (root._jsonSaving) {
            root._jsonSaveQueued = true
            return
        }
        root._jsonSaving = true
        todoFileView.setText(JSON.stringify(root.list))
    }

    function _persistAll() {
        if (root._storageInitializing)
            return
        root._saveJson()
        if (!root._suppressTxtWrite) {
            _writeTxt()
        }
    }

    function _writeTxt() {
        let lines = []
        for (let i = 0; i < root.list.length; i++) {
            const item = root.list[i]
            const checkbox = item.done ? "[x]" : "[ ]"
            lines.push("- " + checkbox + " " + (item.content ?? ""))
        }
        txtFileView.setText(lines.join("\n") + "\n")
    }

    function _finishMissingInitialization(): void {
        root._storageInitializing = false
        root._persistAll()
        startupUnlock.start()
    }

    function _ensureStorageDirectories(): void {
        const jsonParent = root.filePath.substring(0, root.filePath.lastIndexOf('/'))
        const txtParent = root.txtFilePath.substring(0, root.txtFilePath.lastIndexOf('/'))
        const dirs = []
        if (jsonParent.length > 0)
            dirs.push(jsonParent)
        if (txtParent.length > 0 && txtParent !== jsonParent)
            dirs.push(txtParent)
        if (dirs.length === 0) {
            root._finishMissingInitialization()
            return
        }
        if (todoInitDirProc.running)
            return
        todoInitDirProc.command = ["/usr/bin/mkdir", "-p"].concat(dirs)
        todoInitDirProc.attempted = true
        todoInitDirProc.running = true
    }

    // --- Text file parsing ---

    function _parseTxt(text) {
        if (!text || text.trim().length === 0) return []

        const lines = text.split("\n")
        let tasks = []
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim()
            // Skip empty lines and comments
            if (line.length === 0 || line.startsWith("#")) continue

            let content = ""
            let done = false

            // Match: - [x] text  or  [x] text
            const doneMatch = line.match(/^(?:-\s*)?\[x\]\s*(.*)$/i)
            if (doneMatch) {
                content = doneMatch[1].trim()
                done = true
            } else {
                // Match: - [ ] text  or  [ ] text
                const undoneMatch = line.match(/^(?:-\s*)?\[\s?\]\s*(.*)$/)
                if (undoneMatch) {
                    content = undoneMatch[1].trim()
                    done = false
                } else {
                    // Match: - text (dash prefix, no checkbox)
                    const dashMatch = line.match(/^-\s+(.+)$/)
                    if (dashMatch) {
                        content = dashMatch[1].trim()
                        done = false
                    } else {
                        // Plain text line = undone task
                        content = line
                        done = false
                    }
                }
            }

            if (content.length > 0) {
                tasks.push({ "content": content, "done": done })
            }
        }
        return tasks
    }

    // --- Startup ---

    Component.onCompleted: {
        refresh()
    }

    // --- JSON FileView (canonical backend) ---

    FileView {
        id: todoFileView
        path: Qt.resolvedUrl(root.filePath)
        onLoaded: {
            if (root._jsonSaving) {
                root._jsonSaving = false
                if (root._jsonSaveQueued) {
                    root._jsonSaveQueued = false
                    Qt.callLater(() => root._saveJson())
                }
                return
            }

            const fileContents = todoFileView.text()
            try {
                root.list = root._normalizeList(JSON.parse(fileContents))
            } catch (e) {
                console.log("[Todo] JSON parse error, resetting list:", e)
                root.list = []
            }
            _log("[Todo] JSON loaded,", root.list.length, "tasks")
            // Generate txt mirror from loaded JSON, then unlock after settling
            root._writeTxt()
            startupUnlock.start()
        }
        onLoadFailed: (error) => {
            if (error == FileViewError.FileNotFound) {
                console.log("[Todo] JSON not found, creating new file.")
                root.list = []
                root._storageInitializing = true
                root._ensureStorageDirectories()
            } else {
                console.log("[Todo] Error loading JSON:", error)
            }
        }
    }

    Process {
        id: todoInitDirProc
        property bool attempted: false
        property bool startObserved: false
        running: false

        onRunningChanged: {
            if (todoInitDirProc.running) {
                todoInitDirProc.startObserved = false
                return
            }
            if (!todoInitDirProc.attempted || todoInitDirProc.startObserved)
                return
            todoInitDirProc.attempted = false
            root._storageInitializing = false
            console.warn("[Todo] Failed to start storage directory creation")
            root._persistAll()
            startupUnlock.start()
        }

        onStarted: todoInitDirProc.startObserved = true

        onExited: (exitCode, exitStatus) => {
            todoInitDirProc.attempted = false
            if (exitCode === 0) {
                root._finishMissingInitialization()
            } else {
                root._storageInitializing = false
                console.warn("[Todo] Failed to create storage directories, exit code:", exitCode)
                root._persistAll()
                startupUnlock.start()
            }
        }
    }

    // --- TXT FileView (write + watch) ---
    // setText() for writing; onFileChanged for external edit detection.
    // Never call text()/reload() on this — see txtCatProc below.

    FileView {
        id: txtFileView
        path: Qt.resolvedUrl(root.txtFilePath)
        watchChanges: true
        onFileChanged: {
            if (!root._startupLock) {
                txtDebounce.restart()
            }
        }
        onLoadFailed: (error) => {
            if (error == FileViewError.FileNotFound) {
                _log("[Todo] txt not found, will be created on next list change")
            }
        }
    }

    // --- Startup unlock timer ---

    Timer {
        id: startupUnlock
        interval: 800
        repeat: false
        onTriggered: {
            root._startupLock = false
            _log("[Todo] txt sync unlocked")
        }
    }

    // --- Debounce for external txt edits ---

    Timer {
        id: txtDebounce
        interval: 300
        repeat: false
        onTriggered: {
            // Read actual disk content via Process (avoids FileView stale buffer)
            txtCatProc.running = true
        }
    }

    // --- Process to read txt from disk (bypasses FileView cache) ---

    Process {
        id: txtCatProc
        running: false
        command: ["cat", root.txtFilePath]
        stdout: StdioCollector {
            onStreamFinished: {
                const txtContent = text ?? ""
                const parsed = root._parseTxt(txtContent)

                if (root._listsEqual(root.list, parsed)) return

                _log("[Todo] txt changed externally:", parsed.length, "tasks")
                root._suppressTxtWrite = true
                root.list = parsed
                root._saveJson()
                root._suppressTxtWrite = false
            }
        }
    }

    // --- Comparison helper ---

    function _listsEqual(a, b) {
        if (!a || !b) return false
        if (a.length !== b.length) return false
        for (let i = 0; i < a.length; i++) {
            if ((a[i].content ?? "") !== (b[i].content ?? "")) return false
            if (!!a[i].done !== !!b[i].done) return false
        }
        return true
    }
}
