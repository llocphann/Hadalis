#!/usr/bin/env python3
from pathlib import Path
r=Path(__file__).resolve().parents[1]
q=(r/"modules/common/widgets/QuickActionSettingsEditor.qml").read_text()
s=(r/"modules/abyss/settings/AbyssStyleSettings.qml").read_text()
assert "Drag the dotted handle to reorder" not in q
assert "Layout.minimumWidth: 150" in q
assert "root.actionIcon(slot.actionId)" in q
assert "root.actionLabel(slot.actionId)" in q
assert "id: moduleToggleGrid" in s
assert "columns: width >= 980 ? 3 : (width >= 620 ? 2 : 1)" in s
assert "Module functionality settings" not in s
print("quick action row + Abyss modules grid contract: ok")
