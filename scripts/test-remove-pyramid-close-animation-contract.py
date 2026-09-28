#!/usr/bin/env python3
from pathlib import Path
r=Path(__file__).resolve().parents[1]
h=(r/"modules/abyss/AbyssBodyHost.qml").read_text()
c=(r/"modules/abyss/AbyssSurfaceController.qml").read_text()
g=(r/"modules/abyss/looks/AbyssGeometry.js").read_text()
assert "pyramidCloseInward" not in h
assert "pyramidCloseTarget" not in c
assert "closeInward" not in g
assert "readonly property bool placementVisible: placement?.visible !== false" in h
assert "var p = clamp(progress,0,1.035), offset = placement.inward*p;" in g
print("pyramid close animation experiments removed: ok")
