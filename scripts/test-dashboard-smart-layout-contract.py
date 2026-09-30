#!/usr/bin/env python3
from pathlib import Path

root = Path(__file__).resolve().parents[1]
canvas = (root / "modules/dashboard/DashboardCanvas.qml").read_text()
toolbar = (root / "modules/dashboard/DashboardEditToolbar.qml").read_text()

for needle in [
    "function _smartAllLayoutEntries(): var",
    '["welcome","clock","system","github","notes"]',
    '["notifications","agenda","todo","calendar"]',
    '["media","weather"]',
    "const smartEntries = root._smartAllLayoutEntries()",
    "Added and smart-arranged all Dashboard modules",
]:
    assert needle in canvas, needle

for needle in [
    "import qs.modules.abyss.looks",
    "readonly property bool abyssMode:",
    "AbyssStyle.contentPadding",
    "AbyssStyle.surfaceDeep",
    "AbyssStyle.accent",
    "AbyssStyle.textColor",
]:
    assert needle in toolbar, needle

print("dashboard smart layout + Abyss toolbar contract: ok")
