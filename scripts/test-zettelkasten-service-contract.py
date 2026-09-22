#!/usr/bin/env python3
"""Contract guard for Dashboard/Notepad Zettelkasten quick-note capture."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
widget = (ROOT / "modules/sidebarRight/notepad/NotepadWidget.qml").read_text(encoding="utf-8")
service = (ROOT / "services/Zettelkasten.qml").read_text(encoding="utf-8")
qmldir = (ROOT / "services/qmldir").read_text(encoding="utf-8")
config = (ROOT / "modules/common/Config.qml").read_text(encoding="utf-8")
defaults = json.loads((ROOT / "defaults/config.json").read_text(encoding="utf-8"))

for token in (
    'icon: "note_add"',
    'Translation.tr("Save as Zettelkasten quick note")',
    "Zettelkasten.capture(title, textArea.text)",
    'Translation.tr("Saved to Zettelkasten")',
    '/^Note \\d+$/.test(tabTitle)',
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

assert "singleton Zettelkasten 1.0 Zettelkasten.qml" in qmldir
assert "property JsonObject notes: JsonObject {" in config
assert 'property string folder: "00_Capture/03_Zettelkasten"' in config
assert defaults["notes"]["zettelkasten"] == {
    "vaultPath": "",
    "folder": "00_Capture/03_Zettelkasten",
    "defaultType": "Fleeting",
}

print("Zettelkasten quick-note service/UI contract: PASS")
