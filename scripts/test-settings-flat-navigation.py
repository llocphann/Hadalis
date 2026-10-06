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

for source, name in ((window, "settings.qml"), (overlay, "SettingsOverlay.qml")):
    assert "SettingsPageRegistry.navigationPageIndexes(" in source, name
    assert 'type: "header"' not in source, name
    assert "toggleNavGroup(" not in source, name
    assert "navigationIconColor(" in source, name

for token in ("Appearance.colors.colPrimary", "Appearance.colors.colSecondary",
              "Appearance.colors.colTertiary", "function navigationIconColor("):
    assert token in preset, token

for key in ("_retired-18", "_retired-19", "_retired-21", "_retired-27",
            "_retired-28", "_retired-30", "_retired-31", "_retired-35",
            "_retired-36"):
    assert key not in data, key

assert 'key: "automation"' in data
assert 'component: "modules/settings/AutomationConfig.qml"' in data
assert 'if (index === 35) return true' in registry
assert not (ROOT / "modules/settings/TlpConfig.qml").exists()

print("PASS: flat palette-tinted Settings navigation has no retired page components")
