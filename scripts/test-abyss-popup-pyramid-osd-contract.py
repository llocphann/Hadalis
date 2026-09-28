#!/usr/bin/env python3
from pathlib import Path
r=Path(__file__).resolve().parents[1]
host=(r/"modules/abyss/AbyssBodyHost.qml").read_text()
perim=(r/"modules/abyss/AbyssPerimeter.qml").read_text()
place=(r/"modules/abyss/looks/AbyssBodyPlacement.js").read_text()
content=(r/"modules/abyss/content/AbyssOsdContent.qml").read_text()
ctrl=(r/"modules/abyss/AbyssOsdController.qml").read_text()
assert "property bool pyramidStack: false" in host
assert perim.count("pyramidStack: true") >= 2
assert "if (a.pyramidStack && b.pyramidStack && _sameAnchor(a,b))" in place
assert "_requestedArea(b)-_requestedArea(a)" in place
assert 'if (GlobalStates.osdVolumeOpen) kinds.push("volume")' in content
assert 'if (GlobalStates.osdBrightnessOpen) kinds.push("brightness")' in content
assert "RowLayout" in content and "spacing: 10" in content
assert 'const compact=["volume","brightness","mic","keyboardLayout"]' in ctrl
assert "Keep already-active compact" in ctrl
print("popup pyramid + concurrent compact OSD contract: ok")
