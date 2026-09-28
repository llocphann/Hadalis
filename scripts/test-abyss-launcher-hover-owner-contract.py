#!/usr/bin/env python3
from pathlib import Path

r = Path(__file__).resolve().parents[1]
bar_module = (r / "modules/abyss/bar/AbyssBarModule.qml").read_text()
perimeter = (r / "modules/abyss/AbyssPerimeter.qml").read_text()

assert "Shared.StyledPopup {" in bar_module
assert "hoverTarget: launcherAnchor" in bar_module
assert 'liquidPresentationKind: "launcher"' in bar_module
assert 'root.hoverRequest("launcher")' not in bar_module
assert '["wifi","bluetooth","utilities"].includes(kind)' in perimeter
assert '["wifi","bluetooth","utilities","launcher"].includes(kind)' not in perimeter

print("launcher hover is owned by mature StyledPopup: ok")
