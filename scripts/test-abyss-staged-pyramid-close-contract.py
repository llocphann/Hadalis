#!/usr/bin/env python3
from pathlib import Path
r=Path(__file__).resolve().parents[1]
c=(r/"modules/abyss/AbyssSurfaceController.qml").read_text()
h=(r/"modules/abyss/AbyssBodyHost.qml").read_text()
g=(r/"modules/abyss/looks/AbyssGeometry.js").read_text()
assert "function pyramidCloseTarget(identity, closingPlacement, closingRecord): real" in c
assert "Number(nearest.inward ?? 0) + Number(nearest.depth ?? 0)" in c
assert "property real pyramidCloseInward: 0" in h
assert "controller.pyramidCloseTarget(identity," in h
assert "closeInward: root.pyramidCloseInward" in h
assert "var offset = closeInward + (inward-closeInward)*p;" in g
assert "if (p <= .0001 || !placement.visible)" in g
print("staged pyramid close contract: ok")
