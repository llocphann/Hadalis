#!/usr/bin/env python3
"""Contract guard for the dormant Obsidian Todo backend."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
backend = (ROOT / "services" / "ObsidianTodoBackend.qml").read_text(encoding="utf-8")
qmldir = (ROOT / "services" / "qmldir").read_text(encoding="utf-8")
markdown_helper = ROOT / "scripts" / "todo" / "obsidian_todo.py"
runtime_helper = ROOT / "scripts" / "todo" / "obsidian_tasks.py"

required = [
    "Scope {",
    "property bool active: false",
    'property string vaultPath: ""',
    'property string notePath: ""',
    "property bool preferTasksPlugin: true",
    "property bool allowBasicOfflineMutation: true",
    "property var list: []",
    "property bool ready: false",
    "property bool busy: false",
    "property var capabilities:",
    'Quickshell.shellPath("scripts/todo/obsidian_todo.py")',
    'Quickshell.shellPath("scripts/todo/obsidian_tasks.py")',
    '"scan"',
    '"probe-capabilities"',
    '"add-basic"',
    '"toggle-basic"',
    '"toggle-tasks"',
    '"delete"',
    "function toggleTask(taskId: string)",
    "function deleteTask(taskId: string)",
    "function refreshCapabilities(): void",
    "FileView {",
    "watchChanges: root.configured",
    "preload: false",
    "scanDebounce.restart()",
    "capabilityDebounce.restart()",
    "root._taskNeedsTasks(task)",
    "root.capabilities?.richMutationAvailable === true",
    'code === "rich_task_required"',
    "JSON.parse(output)",
]
for snippet in required:
    assert snippet in backend, f"Obsidian backend lost contract: {snippet}"

# QML must never invoke the Obsidian CLI directly. The Python runtime helper
# owns the non-launching process check, lock, active-vault guard and timeout.
assert '["obsidian"' not in backend
assert '"eval"' not in backend
assert "vault=" not in backend

assert markdown_helper.is_file(), "Obsidian Markdown helper is missing"
assert runtime_helper.is_file(), "Obsidian Tasks runtime helper is missing"
assert "ObsidianTodoBackend 1.0 ObsidianTodoBackend.qml" in qmldir

print("Obsidian Todo backend contract: PASS")
