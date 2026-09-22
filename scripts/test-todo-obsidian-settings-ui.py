#!/usr/bin/env python3
"""Contract guard for the unified To-do and Quick Notes settings surface."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
services = (ROOT / "modules" / "settings" / "ServicesConfig.qml").read_text(encoding="utf-8")
facade = (ROOT / "services" / "Todo.qml").read_text(encoding="utf-8")
internal = (ROOT / "services" / "InternalTodoBackend.qml").read_text(encoding="utf-8")

required = [
    'title: Translation.tr("To-do & Quick Notes")',
    'title: Translation.tr("Task source")',
    'Translation.tr("Note path pattern")',
    'Translation.tr("Heading")',
    'id: todoMarkdownNotePattern',
    'id: todoMarkdownHeading',
    'Config.setNestedValue("todo.obsidian.vaultPath", value)',
    'Config.setNestedValue("todo.obsidian.dailyNote.folder", folder)',
    'Config.setNestedValue("todo.obsidian.dailyNote.format", format)',
    'Config.setNestedValue("todo.obsidian.dailyNote.plannerHeading", value)',
    'Config.setNestedValue("todo.obsidian.dailyNote.plannerHeadingLevel", value)',
    'Config.setNestedValue("todo.obsidian.dailyNote.defaultDurationMinutes", value)',
    'Config.setNestedValue("todo.obsidian.sourceMode", "markdown-note")',
    'Todo.beginObsidianSetup()',
    'Todo.cancelObsidianSetup()',
    'Todo.reactivateInternal()',
    'Todo.previewInternalToObsidian()',
    'Todo.migrateInternalToObsidian(',
    'Todo.activateObsidian()',
    'Todo.openObsidianSource()',
    'Translation.tr("Use Obsidian source")',
    'text: Todo.sharedVaultPath',
]
for token in required:
    assert token in services, f"unified Todo settings contract lost: {token}"

todo_start = services.index('title: Translation.tr("To-do & Quick Notes")')
todo_end = services.index('title: Translation.tr("Calendar Sync")', todo_start)
todo = services[todo_start:todo_end]

assert 'Translation.tr("Daily Notes")' not in todo
assert 'Translation.tr("Managed note")' not in todo
assert "Day Planner" not in todo
assert "Planner heading" not in todo
assert "font.pixelSize: Appearance.font.pixelSize.smallest" not in todo
assert 'placeholderText: Translation.tr("~/Documents/Obsidian/My Vault")' not in todo
assert 'placeholderText: "Day Planner"' not in todo
assert todo.count('placeholderText: ""') >= 3

assert 'Config.setNestedValue("todo.backend", "obsidian")' not in services
assert 'Config.setNestedValue("todo.backend", "obsidian")' in facade
assert "readonly property bool useLegacyManagedNote:" in facade
assert "readonly property bool persistenceBusy:" in internal

print("Unified Todo/Obsidian settings UI contract: PASS")

assert '/^\\/+|\\/+$/g' in services
assert '/^\\\\/+|\\\\/+$/g' not in services
