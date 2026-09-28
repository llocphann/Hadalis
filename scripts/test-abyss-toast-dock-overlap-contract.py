#!/usr/bin/env python3
from pathlib import Path
r=Path(__file__).resolve().parents[1]
toast=(r/"modules/abyss/content/AbyssToastContent.qml").read_text()
perim=(r/"modules/abyss/AbyssPerimeter.qml").read_text()
ctrl=(r/"modules/abyss/AbyssSurfaceController.qml").read_text()
assert "Math.max(160," in toast
assert "desiredWidth ?? 180" in perim
assert 'participantOverlapsRect("popup", requestedRecord.surface, 10)' in perim
assert "hasPopupOverlapRect(requestedRecord.surface, 10)" in perim
assert "function participantOverlapsRect(identity, rect, gap = 0): bool" in ctrl
assert "function hasPopupOverlapRect(rect, gap = 0): bool" in ctrl
assert "&& !liquid.hasPopupOnEdge(edge)" not in perim
print("abyss adaptive toast + dock overlap contract: ok")
