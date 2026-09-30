#!/usr/bin/env python3
from pathlib import Path
r=Path(__file__).resolve().parents[1]
bar=(r/"modules/settings/BarConfig.qml").read_text()
ed=(r/"modules/common/widgets/QuickActionSettingsEditor.qml").read_text()
abyss=(r/"modules/abyss/bar/AbyssBarModule.qml").read_text()
assert "Quick Action Settings" in bar and "QuickActionSettingsEditor {}" in bar
assert 'text: "drag_indicator"' in ed
assert '"visibility" : "visibility_off"' in ed
assert 'Config.setNestedValue("bar.utilButtons.order",next)' in ed
assert "showUtilitiesLauncher" in ed
assert "Config.options?.bar?.utilButtons?.showUtilitiesLauncher ?? true" in abyss
print("quick action drag visibility contract: ok")
