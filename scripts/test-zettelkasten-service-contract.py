#!/usr/bin/env python3
"""Contract guard for Dashboard/Notepad Zettelkasten quick-note capture."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
widget = (ROOT / "modules/sidebarRight/notepad/NotepadWidget.qml").read_text(encoding="utf-8")
service = (ROOT / "services/Zettelkasten.qml").read_text(encoding="utf-8")
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
    'Config.options?.notes?.zettelkasten?.vaultPath',
    'Config.options?.todo?.obsidian?.vaultPath',
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
    'title: Translation.tr("Quick Notes & Zettelkasten")',
    'Config.setNestedValue("notes.zettelkasten.vaultPath", value)',
    'Config.setNestedValue("notes.zettelkasten.folder", value)',
    'Config.setNestedValue("notes.zettelkasten.defaultType", newValue)',
    'Translation.tr("Default Zettelkasten type")',
    'value: "Fleeting"',
    'value: "Literature"',
    'value: "Permanent"',
    "Zettelkasten.configuredVaultPath",
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

zettel_start = settings.index('title: Translation.tr("Quick Notes & Zettelkasten")')
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
