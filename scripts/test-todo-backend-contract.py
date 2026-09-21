#!/usr/bin/env python3
"""Contract guard for the Todo facade/backend split."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
facade = (ROOT / "services" / "Todo.qml").read_text(encoding="utf-8")
internal = (ROOT / "services" / "InternalTodoBackend.qml").read_text(encoding="utf-8")
obsidian = (ROOT / "services" / "ObsidianTodoBackend.qml").read_text(encoding="utf-8")
qmldir = (ROOT / "services" / "qmldir").read_text(encoding="utf-8")

required_facade = [
    "InternalTodoBackend {",
    "ObsidianTodoBackend {",
    "DailyNoteTodoBackend {",
    'Config.options?.todo?.obsidian?.sourceMode ?? "managed-note"',
    'root.obsidianSourceMode === "daily-note"',
    "readonly property var obsidianBackend:",
    'Config.options?.todo?.backend ?? "internal"',
    'root.requestedBackend === "obsidian"',
    "active: root.useObsidian || root._obsidianSetupActive",
    "property bool _migrationInFlight: false",
    "readonly property var list: root.useObsidian ? root.obsidianBackend.list : internal.list",
    "readonly property bool ready:",
    "readonly property bool busy: root.useObsidian ? obsidian.busy : root._migrationInFlight",
    "readonly property string errorMessage:",
    "readonly property var capabilities:",
    "readonly property string sourceLabel:",
    "property alias filePath: internal.filePath",
    "property alias txtFilePath: internal.txtFilePath",
    "return internal.addItem(item)",
    "return internal.addTask(desc)",
    "return internal.markDone(index)",
    "return internal.markUnfinished(index)",
    "return internal.deleteItem(index)",
    "return root.obsidianBackend.toggleTask(String(item.id ?? \"\"))",
    "return root.obsidianBackend.deleteTask(String(item.id ?? \"\"))",
    "function addTaskWithTime(desc, startTime, endTime)",
    "readonly property bool obsidianSetupActive: root._obsidianSetupActive",
    "readonly property bool obsidianReady: obsidian.ready",
    "readonly property var obsidianMigrationPreview: obsidian.migrationPreview",
    "function beginObsidianSetup(): bool",
    "function cancelObsidianSetup(): void",
    "function initializeSection()",
    "function previewInternalToObsidian(): bool",
    "readonly property int internalItemCount: internal.list.length",
    "function migrateInternalToObsidian(expectedInternalSha)",
    "root._activateAfterMigration = staging",
    "root._migrationInFlight = staging",
    "function onMigrationFinished(success, payload): void",
    "obsidian.migrateInternal(",
    "function activateObsidian(): bool",
    "function reactivateInternal(): bool",
    'Config.setNestedValue("todo.backend", "obsidian")',
    'Config.setNestedValue("todo.backend", "internal")',
    "function openObsidianSource(): bool",
    "function toggleTask(taskId)",
    "function deleteTask(taskId)",
    "function openSource(taskId)",
    '"obsidian://open?path=" + encodeURIComponent(obsidian.noteFullPath)',
]
for snippet in required_facade:
    assert snippet in facade, f"Todo facade lost contract: {snippet}"

assert "FileView {" not in facade, "persistence leaked into Todo facade"
assert "Process {" not in facade, "process implementation leaked into Todo facade"
assert '"internal"' in facade, "internal backend default/fallback disappeared"
assert "readonly property var list: root.useObsidian ? root.obsidianBackend.list : internal.list" in facade
assert "root._obsidianSetupActive ? obsidian.list" not in facade, "staging backend leaked into public canonical list"

required_internal = [
    "Scope {",
    "property string filePath: Directories.todoPath",
    "property string txtFilePath: Directories.todoTxtPath",
    "property var list: []",
    "property bool ready: false",
    "function addTask(desc)",
    "function markDone(index)",
    "function markUnfinished(index)",
    "function deleteItem(index)",
    "function refresh()",
    "function _parseTxt(text)",
    "FileView {",
    "Process {",
]
for snippet in required_internal:
    assert snippet in internal, f"internal Todo backend lost behavior: {snippet}"

assert "pragma Singleton" not in internal, "internal backend must not become a second singleton"
assert facade.count("if (root._migrationInFlight)") >= 7, "internal mutations must freeze during migration"
assert "signal migrationFinished(bool success, var payload)" in obsidian
assert 'root._notifyMigrationFinished(false, null)' in obsidian
assert 'root._notifyMigrationFinished(true, payload)' in obsidian

assert "InternalTodoBackend 1.0 InternalTodoBackend.qml" in qmldir
assert "ObsidianTodoBackend 1.0 ObsidianTodoBackend.qml" in qmldir
assert "DailyNoteTodoBackend 1.0 DailyNoteTodoBackend.qml" in qmldir
assert "singleton Todo 1.0 Todo.qml" in qmldir

print("Todo facade/backend contract: PASS")
