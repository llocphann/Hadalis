#!/usr/bin/env python3
"""Contract guard for the Todo facade/backend split."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
facade = (ROOT / "services" / "Todo.qml").read_text(encoding="utf-8")
internal = (ROOT / "services" / "InternalTodoBackend.qml").read_text(encoding="utf-8")
qmldir = (ROOT / "services" / "qmldir").read_text(encoding="utf-8")

required_facade = [
    "InternalTodoBackend {",
    "ObsidianTodoBackend {",
    'Config.options?.todo?.backend ?? "internal"',
    'root.requestedBackend === "obsidian"',
    "active: root.useObsidian",
    "readonly property var list:",
    "readonly property bool ready:",
    "readonly property bool busy:",
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
    "return obsidian.toggleTask(String(item.id ?? \"\"))",
    "return obsidian.deleteTask(String(item.id ?? \"\"))",
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
assert "InternalTodoBackend 1.0 InternalTodoBackend.qml" in qmldir
assert "ObsidianTodoBackend 1.0 ObsidianTodoBackend.qml" in qmldir
assert "singleton Todo 1.0 Todo.qml" in qmldir

print("Todo facade/backend contract: PASS")
