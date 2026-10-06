#!/usr/bin/env python3
"""Flat Settings navigation and retired-page cleanup contract."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")

data = read("modules/settings/SettingsPageRegistryData.qml")
registry = read("modules/settings/SettingsPageRegistry.qml")
preset = read("modules/common/widgets/SettingsMaterialPreset.qml")
window = read("settings.qml")
overlay = read("modules/settings/SettingsOverlay.qml")
arrange = read("modules/settings/ArrangeConfig.qml")
edit_pane = read("modules/settings/SettingsNavEditPane.qml")
arrangement = read("modules/settings/SettingsArrangement.qml")

for source, name in ((window, "settings.qml"), (overlay, "SettingsOverlay.qml")):
    assert "SettingsPageRegistry.navigationPageIndexes(" in source, name
    assert 'type: "header"' not in source, name
    assert "toggleNavGroup(" not in source, name
    assert "navigationIconColor(" in source, name

for token in ("Appearance.colors.colPrimary", "Appearance.colors.colSecondary",
              "Appearance.colors.colTertiary", "function navigationIconColor("):
    assert token in preset, token

for source, name in ((arrange, "ArrangeConfig.qml"), (edit_pane, "SettingsNavEditPane.qml")):
    assert "CategoryCard" not in source, name
    assert "CategoryBlock" not in source, name
    assert "category.label" not in source, name
    assert "groupDragging" not in source, name
    assert "navigationPageIndexes(false)" in source, name
assert "function movePageFlat(" in arrangement
assert "function hidePageById(" in arrangement

for key in ("_retired-18", "_retired-19", "_retired-21", "_retired-27",
            "_retired-28", "_retired-30", "_retired-31", "_retired-35",
            "_retired-36"):
    assert key not in data, key

assert 'key: "automation"' not in data
assert "AutomationConfig.qml" not in data
assert not (ROOT / "modules/settings/TlpConfig.qml").exists()

print("PASS: flat palette-tinted Settings navigation has no retired page components")
