#!/usr/bin/env python3
from pathlib import Path

r = Path(__file__).resolve().parents[1]
editor = (r / "modules/abyss/AbyssEdgeEditor.qml").read_text()
bar = (r / "modules/abyss/bar/AbyssBar.qml").read_text()
perimeter = (r / "modules/abyss/AbyssPerimeter.qml").read_text()
presentation = (r / "modules/abyss/looks/AbyssPresentation.js").read_text()

assert '"utilities","launcher"' in editor
assert "popupJoinedEdge: placement?.joinCorner" in bar
assert "hostedPopup?._liquidAnchor?.popupJoinedEdge" in perimeter
assert '"launcher"' in presentation
assert "function canJoin(kind)" in presentation

print("launcher live-editor Join Edge follows mature popup path: ok")
