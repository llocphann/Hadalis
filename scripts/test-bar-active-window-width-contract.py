#!/usr/bin/env python3
"""Ensure Active Window width uses the same persistent bounded pattern as Media."""

import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
def read(path):
    return (root / path).read_text(encoding="utf-8")
active = read("modules/bar/ActiveWindow.qml")
bar = read("modules/abyss/bar/AbyssBarModule.qml")
classic = read("modules/bar/BarContent.qml")
settings = read("modules/settings/BarConfig.qml")
typed = read("modules/common/Config.qml")
defaults = json.loads(read("defaults/config.json"))
assert "Config.options?.bar?.activeWindow?.width ?? 220" in active
assert "Math.max(120, Math.min(420, configured))" in active
assert "readonly property real maxContentWidth:" in active
assert "Math.min(item.maxContentWidth ?? 220," in bar
assert "Math.max(60,item.contentImplicitWidth)" in bar
assert "Math.min(_awItem.contentImplicitWidth, _awItem.maxContentWidth)" in classic
assert 'text: Translation.tr("Active window max width (px)")' in settings
assert 'Config.setNestedValue("bar.activeWindow.width", value)' in settings
assert "to: 420" in settings
assert 'property JsonObject activeWindow: JsonObject {\n                    property bool showTitle: true\n                    property int width: 220' in typed
assert defaults["bar"]["activeWindow"]["width"] == 220
print("PASS: Active Window max-width typed/defaults/settings/classic/Abyss contracts")
