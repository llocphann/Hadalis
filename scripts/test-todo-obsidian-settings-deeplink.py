#!/usr/bin/env python3
"""Guard Todo/Obsidian Settings deep links from dashboard surfaces."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
states = (ROOT / "GlobalStates.qml").read_text(encoding="utf-8")
services = (ROOT / "modules" / "settings" / "ServicesConfig.qml").read_text(encoding="utf-8")
registry = (ROOT / "modules" / "settings" / "SettingsPageRegistryData.qml").read_text(encoding="utf-8")
overlay = (ROOT / "modules" / "settings" / "SettingsOverlay.qml").read_text(encoding="utf-8")
focus = (ROOT / "modules" / "settings" / "SettingsFocus.qml").read_text(encoding="utf-8")
window = (ROOT / "settings.qml").read_text(encoding="utf-8")

for token in (
    'property string settingsOverlayRequestedSection: ""',
    "function openSettingsSection(index: int, section: string): void",
    '"QS_SETTINGS_SECTION=" + targetSection',
):
    assert token in states, f"missing settings deep-link contract: {token}"

assert 'Quickshell.env("QS_SETTINGS_SECTION")' in window
assert "function activateSettingsSearchSection(section: string): bool" in services
assert 'label.includes("todo") || label.includes("obsidian")' in services
assert 'root.activeSection = "data"' in services

assert 'pageIndex: 7, pageName: root.pages[7].name' in registry
assert 'section: Translation.tr("Todo & Obsidian")' in registry
assert '"obsidian"' in registry and '"vault"' in registry

for name, source in (("rail", overlay), ("focus", focus)):
    assert "settingsOverlayRequestedSection" in source, f"{name} overlay lost section deep link"
    assert "consumeSettingsDeepLink" in source, f"{name} overlay lost deep-link consumer"

print("Todo/Obsidian settings deep-link contract: PASS")
