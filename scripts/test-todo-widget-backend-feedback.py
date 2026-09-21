#!/usr/bin/env python3
"""Guard Todo widget backend-aware error and source routing."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
widget = (ROOT / "modules" / "sidebarRight" / "todo" / "TodoWidget.qml").read_text(encoding="utf-8")

assert 'onClicked: Todo.openSource("")' in widget
assert widget.count("Todo.errorMessage.length > 0") >= 2
assert widget.count("? Todo.errorMessage") >= 2

print("Todo widget backend feedback contract: PASS")
