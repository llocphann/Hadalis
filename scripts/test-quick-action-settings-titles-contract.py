#!/usr/bin/env python3
from pathlib import Path

root = Path(__file__).resolve().parents[1]
editor = (root / "modules/common/widgets/QuickActionSettingsEditor.qml").read_text()
catalog = (root / "translations/en_US.json").read_text()

labels = (
    "Screenshot", "Screen record", "Color picker", "Notepad",
    "On-screen keyboard", "Keyboard layout", "Microphone", "Screen cast",
    "Dark / light mode", "Power profile", "Utilities",
)
for label in labels:
    assert f'"{label}"' in editor
    assert f'"{label}"' in catalog

assert 'text: root.actionLabel(slot.actionId)' in editor
assert 'return String(translated ?? "").trim().length > 0 ? translated : source' in editor
assert 'visible: true' in editor
assert 'opacity: 1' in editor
assert 'font.weight: Font.Medium' in editor
assert 'text: "drag_indicator"' in editor
assert 'root.configuredVisible(slot.actionId) ? "visibility" : "visibility_off"' in editor

print("quick action settings titles contract: ok")
