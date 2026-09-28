#!/usr/bin/env python3
from pathlib import Path
r=Path(__file__).resolve().parents[1]
d=(r/"modules/bar/DistroIcon.qml").read_text()
a=(r/"modules/abyss/bar/AbyssBarModule.qml").read_text()
p=(r/"modules/abyss/content/AbyssPopupContent.qml").read_text()
c=(r/"modules/abyss/content/AbyssLauncherControlsPopup.qml").read_text()
assert "signal abyssControlsHoverChanged(bool hovered)" in d
assert "StyledToolTip" not in d
assert 'root.hoverState("launcher", hovered)' in a
assert 'root.hoverRequest("launcher")' in a
assert '"launcher"].includes(root.kind)' in p
assert 'root.kind === "launcher" ? launcher' in p
assert "Surface Performance" in c and "Wave Preset" in c
assert 'Config.setNestedValue("abyss.quality", value)' in c
assert 'updates["abyss.waves." + key]' in c
print("abyss launcher preset popup contract: ok")
