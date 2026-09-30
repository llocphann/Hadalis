#!/usr/bin/env python3
from pathlib import Path
r=Path(__file__).resolve().parents[1]
u=(r/"modules/bar/UtilButtons.qml").read_text()
b=(r/"modules/settings/BarConfig.qml").read_text()
c=(r/"modules/common/Config.qml").read_text()
d=(r/"defaults/config.json").read_text()
assert "readonly property var utilityOrder:" in u
assert 'root.utilityIndex("utilities")' in u
assert "root.visibleUtilityCount" in u
assert "Quick Action icon order" in b
assert 'Config.setNestedValue("bar.utilButtons.order",next)' in b
assert 'property list<string> order:' in c
assert '"order": [' in d
print("quick action icon ordering contract: ok")
