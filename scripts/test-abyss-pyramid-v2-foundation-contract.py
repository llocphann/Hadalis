#!/usr/bin/env python3
from pathlib import Path

r=Path(__file__).resolve().parents[1]
host=(r/"modules/abyss/AbyssBodyHost.qml").read_text()
placement=(r/"modules/abyss/looks/AbyssBodyPlacement.js").read_text()
motion=(r/"modules/abyss/looks/AbyssPyramidMotion.js").read_text()

# New architecture must keep allocator and animation ownership separate.
assert 'property string stackPolicy: ""' in host
assert "property var semanticOpenOverride: undefined" in host
assert "open:root.semanticOpen" in host
assert "stackPolicy:root.stackPolicy" in host
assert "root.semanticOpen && root.placementVisible" in host
assert "(root.residentContent || root.visualResident)" in host

# Static same-anchor ordering is deterministic and contains no close lifecycle.
assert 'a?.stackPolicy === "pyramid"' in placement
assert "_requestedArea(b)-_requestedArea(a)" in placement
for forbidden in ("closeInward","closeTarget","closingProgress"):
    assert forbidden not in placement

# Presentation helper interpolates only this popup's own record; tangent
# along/span come from the final record and are never borrowed from a peer.
assert "function collapsedRecord(full,lower)" in motion
assert "function interpolateRecord(from,to,progress)" in motion
assert "result.along=_number(to.along,0)" in motion
assert "result.span=Math.max(0,_number(to.span,0))" in motion

print("Pyramid Popup v2 foundation contract: ok")
