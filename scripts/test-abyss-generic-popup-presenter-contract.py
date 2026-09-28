#!/usr/bin/env python3
from pathlib import Path

r=Path(__file__).resolve().parents[1]
p=(r/"modules/abyss/AbyssGenericPopupPresenter.qml").read_text()
per=(r/"modules/abyss/AbyssPerimeter.qml").read_text()
host=(r/"modules/abyss/AbyssBodyHost.qml").read_text()

assert "AbyssGenericPopupPresenter {" in per
assert 'identity: "popup"' in p
assert "property string activeKind" in p
assert "function beginRetract(): void" in p
assert "function finishRetract(): void" in p
assert "if (desired === root.activeKind)" in p
assert "root.beginRetract()" in p
assert "root.latch(desired)" in p
assert "animatePlacementChanges: false" in p
assert "animatePresentation: false" in p
assert "placementCanResize: false" in p
assert "externalProgress: root.revealProgress" in p
assert "Presentation.joinedEdge(root.activeKind" in p
assert "AbyssPopupTransitionCoordinator" not in p
assert "pyramidStack" not in p
print("single-owner generic Abyss popup presenter contract: ok")
