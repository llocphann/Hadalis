#!/usr/bin/env python3
"""Contract guard for the read-only Obsidian Todo backend."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
backend = (ROOT / "services" / "ObsidianTodoBackend.qml").read_text(encoding="utf-8")
qmldir = (ROOT / "services" / "qmldir").read_text(encoding="utf-8")
helper = ROOT / "scripts" / "todo" / "obsidian_todo.py"

required = [
    "Scope {",
    "property bool active: false",
    'property string vaultPath: ""',
    'property string notePath: ""',
    "property var list: []",
    "property bool ready: false",
    "property bool busy: false",
    'property string _scanVaultPath: ""',
    'property string _scanNotePath: ""',
    'Quickshell.shellPath("scripts/todo/obsidian_todo.py")',
    '"/usr/bin/python3"',
    '"scan"',
    '"--vault", root.vaultPath',
    '"--note", root.notePath',
    "FileView {",
    "watchChanges: root.configured",
    "preload: false",
    "scanDebounce.restart()",
    "interval: 5000",
    "JSON.parse(output)",
    "root._scanVaultPath !== root.vaultPath",
    "root._scanNotePath !== root.notePath",
]
for snippet in required:
    assert snippet in backend, f"Obsidian read backend lost contract: {snippet}"

for forbidden in [
    "setText(",
    "writeAdapter(",
    "execDetached(",
    '"toggle"',
    '"delete"',
    '"add"',
]:
    assert forbidden not in backend, f"read-only backend gained mutation path: {forbidden}"

assert helper.is_file(), "Obsidian Todo scanner helper is missing"
assert "ObsidianTodoBackend 1.0 ObsidianTodoBackend.qml" in qmldir

print("Obsidian Todo read backend contract: PASS")
