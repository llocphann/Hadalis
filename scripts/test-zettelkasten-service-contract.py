#!/usr/bin/env python3
"""Contract guard for Dashboard/Notepad Zettelkasten quick-note capture."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
widget = (ROOT / "modules/sidebarRight/notepad/NotepadWidget.qml").read_text(encoding="utf-8")
service = (ROOT / "services/Zettelkasten.qml").read_text(encoding="utf-8")
todo_service = (ROOT / "services/Todo.qml").read_text(encoding="utf-8")
dash = (ROOT / "modules/dashboard/DashNotes.qml").read_text(encoding="utf-8")
helper = (ROOT / "scripts" / "notes" / "zettelkasten.py").read_text(encoding="utf-8")
settings = (ROOT / "modules" / "settings" / "ServicesConfig.qml").read_text(encoding="utf-8")
qmldir = (ROOT / "services/qmldir").read_text(encoding="utf-8")
config = (ROOT / "modules/common/Config.qml").read_text(encoding="utf-8")
defaults = json.loads((ROOT / "defaults/config.json").read_text(encoding="utf-8"))

for token in (
    'icon: "note_add"',
    'Translation.tr("Save as Zettelkasten quick note")',
    "Zettelkasten.capture(title, draftText)",
    "function saveAsZettel(): bool",
    "function captureQuickNote(): bool",
    "readonly property bool canSaveZettel:",
    'Translation.tr("Saved to Zettelkasten")',
    '/^Note \\d+$/.test(tabTitle)',
    "Notepad.setTextValue(textArea.text)",
    "draft cleanup remains an explicit user action",
    "property bool compactPresentation: false",
    "visible: !root.compactPresentation",
    "visible: root.compactPresentation",
):
    assert token in widget, f"Notepad Zettelkasten UI contract lost: {token}"

for token in (
    "pragma Singleton",
    'Quickshell.shellPath("scripts/notes/zettelkasten.py")',
    "function capture(title, body): bool",
    "readonly property string configuredVaultPath: Todo.sharedVaultPath",
    '?? "00_Capture/03_Zettelkasten"',
    '?? "Fleeting"',
    "signal captured(var payload)",
):
    assert token in service, f"Zettelkasten service contract lost: {token}"

for token in (
    'Translation.tr("Quick Notes")',
    'Translation.tr("Zettelkasten capture")',
    'Translation.tr("%1 note · draft stays in Notepad")',
    ".arg(Zettelkasten.defaultType)",
    "Zettelkasten.errorMessage.length > 0",
    "enabled: notepad.canSaveZettel",
    "onClicked: notepad.captureQuickNote()",
    "compactPresentation: true",
    "margin: 0",
    "readonly property bool constrainedHeight:",
    "Layout.minimumHeight: root.constrainedHeight ? 76 : 130",
):
    assert token in dash, f"Dashboard Notes Zettelkasten contract lost: {token}"

for token in (
    'ALLOWED_TYPES = ("Permanent", "Literature", "Fleeting")',
    'DEFAULT_FOLDER = "00_Capture/03_Zettelkasten"',
    'DEFAULT_TYPE = "Fleeting"',
    '"## Core Idea"',
    '"## Content"',
    '"## Context & Connections"',
    '"## Sources & References"',
    '"aliases: []"',
    '"templateCompatible": True',
):
    assert token in helper, f"Zettelkasten helper lost vault-template contract: {token}"

for token in (
    'title: Translation.tr("To-do & Quick Notes")',
    'title: Translation.tr("Quick Notes")',
    'text: Todo.sharedVaultPath',
    'Config.setNestedValue("todo.obsidian.vaultPath", value)',
    'Config.setNestedValue("notes.zettelkasten.folder", value)',
    'Config.setNestedValue("notes.zettelkasten.defaultType", newValue)',
    'Translation.tr("Default Zettelkasten type")',
    'value: "Fleeting"',
    'value: "Literature"',
    'value: "Permanent"',
    "Zettelkasten.folder",
):
    assert token in settings, f"Zettelkasten settings contract lost: {token}"

assert "singleton Zettelkasten 1.0 Zettelkasten.qml" in qmldir
assert "property JsonObject notes: JsonObject {" in config
assert 'property string folder: "00_Capture/03_Zettelkasten"' in config
assert defaults["notes"]["zettelkasten"] == {
    "vaultPath": "",
    "folder": "00_Capture/03_Zettelkasten",
    "defaultType": "Fleeting",
}

print("Zettelkasten quick-note service/UI contract: PASS")

unified_start = settings.index('title: Translation.tr("To-do & Quick Notes")')
zettel_start = settings.index('title: Translation.tr("Quick Notes")', unified_start)
zettel_end = settings.index('title: Translation.tr("Calendar Sync")', zettel_start)
zettel_settings = settings[zettel_start:zettel_end]
assert "font.pixelSize: Appearance.font.pixelSize.smallest" not in zettel_settings
assert "color: Appearance.colors.colSubtext" not in zettel_settings
assert 'placeholderText: Translation.tr("Leave blank to reuse the Todo Obsidian vault")' not in zettel_settings
assert 'placeholderText: "00_Capture/03_Zettelkasten"' not in zettel_settings

assert 'Translation.tr("Create a Fleeting Zettelkasten note.' not in dash
assert "font.pixelSize: Appearance.font.pixelSize.smallest" not in dash
assert "_clearCapturedDraft" not in widget
assert "_pendingZettelCapture" not in widget
assert "Notepad.removeTab(index)" not in widget
assert "draft clears after verified save" not in dash
assert 'text: Translation.tr("Capture")' not in dash

# A single settings card and one editable shared vault must feed both services.
unified_settings = settings[unified_start:zettel_end]
assert settings.count('title: Translation.tr("To-do & Quick Notes")') == 1
assert 'title: Translation.tr("Quick Notes & Zettelkasten")' not in settings
assert unified_settings.count('id: todoObsidianVaultPath') == 1
assert 'id: zettelkastenVaultPath' not in unified_settings
assert 'Translation.tr("Vault path override")' not in unified_settings
assert 'Translation.tr("Canonical task store")' not in unified_settings
assert "readonly property string sharedVaultPath:" in todo_service
assert 'Config.options?.todo?.obsidian?.vaultPath ?? ""' in todo_service
assert 'Config.options?.notes?.zettelkasten?.vaultPath ?? ""' in todo_service
assert todo_service.count("vaultPath: root.sharedVaultPath") == 2
assert "readonly property string configuredVaultPath: Todo.sharedVaultPath" in service
assert 'Config.setNestedValue("notes.zettelkasten.vaultPath", "")' in unified_settings
assert "notes.zettelkasten.vaultPath" not in service
assert 'GlobalStates.openSettingsSection(7, "To-do & Quick Notes")' in dash
