#!/usr/bin/env python3
from pathlib import Path
r=Path(__file__).resolve().parents[1]
h=(r/"modules/abyss/AbyssBodyHost.qml").read_text()
p=(r/"modules/abyss/AbyssPerimeter.qml").read_text()
assert "property var semanticOpenOverride: undefined" in h
assert "semanticOpenOverride === undefined" in h
assert "root.semanticOpen && root.placementVisible" in h
assert "root.open || root.progress > 0.001" in h
assert "semanticOpenOverride:" in p
assert "hostedPopup?.requestedVisible ?? false" in p
print("StyledPopup semantic/visual lifecycle split contract: ok")
