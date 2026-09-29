#!/usr/bin/env python3
from pathlib import Path

root = Path(__file__).resolve().parents[1]
editor = (root / "modules/common/widgets/QuickActionSettingsEditor.qml").read_text()
catalog = (root / "translations/en_US.json").read_text()
runtime = (root / "modules/bar/UtilButtons.qml").read_text()

labels = (
    "Screenshot", "Screen record", "Color picker", "Notepad",
    "On-screen keyboard", "Keyboard layout", "Microphone", "Screen cast",
    "Dark / light mode", "Power profile", "Utilities",
)
for label in labels:
    assert f'"{label}"' in editor
    assert f'"{label}"' in catalog

assert "import qs.services" in editor
assert 'text: root.actionLabel(slot.actionId)' in editor
assert 'return String(translated ?? "").trim().length > 0 ? translated : source' in editor
assert 'font.weight: Font.Medium' in editor

assert "readonly property var activeActions:" in editor
assert "readonly property var unusedActions:" in editor
assert "orientation: ListView.Horizontal" in editor
assert "model: root.unusedActions" in editor
assert "model: root.activeActions" in editor
assert "function removeAction(id): void" in editor
assert "function addAction(id): void" in editor
assert 'Translation.tr("Remove from Quick Actions")' in editor
assert 'Translation.tr("Add to Quick Actions")' in editor
assert 'text: "remove_circle"' in editor
assert 'text: "drag_indicator"' in editor

# Screen cast and Utilities use the Settings icons as the canonical runtime glyphs.
assert 'screenCast:"cast"' in editor
assert 'utilities:"tune"' in editor
screen_cast_block = runtime[runtime.index('active: root.utilityActive("screenCast")'):]
screen_cast_block = screen_cast_block[:screen_cast_block.index('active: root.utilityActive("darkMode")')]
assert 'text: "cast"' in screen_cast_block
utilities_block = runtime[runtime.index('active: root.utilityActive("utilities")'):]
assert 'text: "tune"' in utilities_block
assert 'text: "display_settings"' not in utilities_block

assert 'root.configuredVisible(slot.actionId) ? "visibility" : "visibility_off"' not in editor
assert 'Translation.tr("Hide Quick Action")' not in editor
assert 'Translation.tr("Show Quick Action")' not in editor

print("quick action settings titles/tray contract: ok")
