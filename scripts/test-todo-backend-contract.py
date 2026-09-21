#!/usr/bin/env python3
"""Contract guard for the Todo facade/internal-backend split."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
facade = (ROOT / "services" / "Todo.qml").read_text(encoding="utf-8")
backend = (ROOT / "services" / "InternalTodoBackend.qml").read_text(encoding="utf-8")
qmldir = (ROOT / "services" / "qmldir").read_text(encoding="utf-8")

required_facade = [
    "InternalTodoBackend {",
    "property alias filePath: internal.filePath",
    "property alias txtFilePath: internal.txtFilePath",
    "property alias list: internal.list",
    "property alias ready: internal.ready",
    "return internal.addItem(item)",
    "return internal.addTask(desc)",
    "return internal.markDone(index)",
    "return internal.markUnfinished(index)",
    "return internal.deleteItem(index)",
    "internal.refresh()",
]
for snippet in required_facade:
    assert snippet in facade, f"Todo facade lost contract: {snippet}"

assert "FileView {" not in facade, "persistence leaked back into Todo facade"
assert "Process {" not in facade, "persistence process leaked back into Todo facade"

required_backend = [
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
for snippet in required_backend:
    assert snippet in backend, f"internal Todo backend lost behavior: {snippet}"

assert "pragma Singleton" not in backend, "internal backend must not become a second singleton"
assert "InternalTodoBackend 1.0 InternalTodoBackend.qml" in qmldir
assert "singleton Todo 1.0 Todo.qml" in qmldir

print("Todo facade/internal backend contract: PASS")
