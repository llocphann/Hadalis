#!/usr/bin/env python3
from pathlib import Path
r=Path(__file__).resolve().parents[1]
q=(r/"modules/common/widgets/QuickActionSettingsEditor.qml").read_text()
l=(r/"modules/bar/DistroIcon.qml").read_text()
d=(r/"modules/dashboard/DashboardCanvas.qml").read_text()
for n in ["function actionLabel(id): string","function actionIcon(id): string",
          "readonly property string actionId: String(modelData ?? \"\")",
          "root.actionIcon(slot.actionId)","root.actionLabel(slot.actionId)",
          "Appearance.colors.colOnLayer1"]:
    assert n in q,n
assert "useParentHover: false" in l and "externalHoverState: statusHover.hovered" in l
assert 'const committed = Config.options?.dashboard?.canvas?.widgets ?? []' in d
assert "committed.length > 0 ? committed : root.defaultEntries()" in d
print("quick action identity + launcher popup + dashboard baseline contract: ok")
