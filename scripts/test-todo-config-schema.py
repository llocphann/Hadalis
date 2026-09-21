#!/usr/bin/env python3
"""Contract guard for the append-only Todo backend configuration schema."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
config_qml = (ROOT / "modules" / "common" / "Config.qml").read_text(encoding="utf-8")
defaults = json.loads((ROOT / "defaults" / "config.json").read_text(encoding="utf-8"))

required_qml = [
    "property JsonObject todo: JsonObject {",
    'property string backend: "internal"',
    "property JsonObject obsidian: JsonObject {",
    'property string vaultPath: ""',
    'property string notePath: "Hadalis/Todo.md"',
    'property string scope: "managed-section"',
    "property bool preferTasksPlugin: true",
    "property bool allowBasicOfflineMutation: true",
]
for snippet in required_qml:
    assert snippet in config_qml, f"Todo config schema lost: {snippet}"

expected = {
    "backend": "internal",
    "obsidian": {
        "vaultPath": "",
        "notePath": "Hadalis/Todo.md",
        "scope": "managed-section",
        "preferTasksPlugin": True,
        "allowBasicOfflineMutation": True,
    },
}
assert defaults.get("todo") == expected, "defaults/config.json Todo defaults drifted"
assert defaults["todo"]["backend"] == "internal", "Obsidian must remain opt-in"

print("Todo backend config schema contract: PASS")
