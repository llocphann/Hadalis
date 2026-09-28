#!/usr/bin/env python3
from pathlib import Path

r = Path(__file__).resolve().parents[1]
d = (r / "modules/bar/DistroIcon.qml").read_text()
a = (r / "modules/abyss/bar/AbyssBarModule.qml").read_text()
p = (r / "modules/abyss/content/AbyssPopupContent.qml").read_text()
c = (r / "modules/abyss/content/AbyssLauncherControlsPopup.qml").read_text()
host = (r / "modules/abyss/AbyssPopup.qml").read_text()

assert "signal abyssControlsHoverChanged(bool hovered)" in d
assert "StyledToolTip" not in d
assert 'root.hoverState("launcher", hovered)' in a
assert 'root.hoverRequest("launcher")' in a
assert '"launcher"].includes(root.kind)' in p
assert 'root.kind === "launcher" ? launcher' in p

# abyss.quality is a surface performance policy, not a wave preset.
assert "Surface Performance" in c
assert "Wave Preset" in c
assert 'Config.setNestedValue("abyss.quality", value)' in c
assert 'updates["abyss.waves." + key]' in c

# The Launcher body owns an explicit icon + text row and cannot collapse into
# the icon-only AbyssButton compact presentation.
assert "component PopupChoice: AbstractButton" in c
assert "MaterialSymbol {" in c
assert "AbyssLabel {" in c
assert "text: choice.text" in c
assert "AbyssButton" not in c
assert "implicitWidth: 360" in c
assert "Layout.minimumWidth: 300" in c
assert "Layout.minimumWidth: 150" in c

# The rebuilt generic popup keeps the full requested content size.
assert "placementCanResize: false" in host

print("abyss launcher popup text + preset contract: ok")
