#!/usr/bin/env python3
from pathlib import Path

r=Path(__file__).resolve().parents[1]
editor=(r/"modules/abyss/AbyssEdgeEditor.qml").read_text()
bar=(r/"modules/abyss/bar/AbyssBar.qml").read_text()
bar_module=(r/"modules/abyss/bar/AbyssBarModule.qml").read_text()
perimeter=(r/"modules/abyss/AbyssPerimeter.qml").read_text()
presentation=(r/"modules/abyss/looks/AbyssPresentation.js").read_text()

assert '"utilities","launcher"' in editor
assert 'onToggled:root.change("joinCorner",checked)' in editor
assert "popupJoinedEdge: placement?.joinCorner" in bar
assert "Shared.StyledPopup {" in bar_module
assert "hoverTarget: launcherAnchor" in bar_module
assert 'liquidPresentationKind: "launcher"' in bar_module
assert "hostedPopup?._liquidAnchor?.popupJoinedEdge" in perimeter
assert "Presentation.joinedEdge(presentationKind" in perimeter
assert '"launcher"' in presentation
assert "function canJoin(kind)" in presentation
assert "function nearbyEdge(" in presentation
assert "function joinedEdge(" in presentation

print("launcher live-editor Join Edge follows mature source-owned popup path: ok")
