#!/usr/bin/env python3
from pathlib import Path
r=Path(__file__).resolve().parents[1]
x=(r/"modules/abyss/AbyssPopupTransitionCoordinator.qml").read_text()
h=(r/"modules/abyss/AbyssBodyHost.qml").read_text()
c=(r/"modules/abyss/AbyssSurfaceController.qml").read_text()

assert "property bool motionEnabled: true" in x
assert "property real transactionProgress: 1" in x
assert "function syncResting(placements,participants): void" in x
assert "function beginClosing(identity): void" in x
assert "function finishClosing(identity,placements,participants): void" in x
assert "Behavior on transactionProgress" in x
assert "readonly property bool coordinatedPyramidMotion:" in h
assert "readonly property var pyramidVisualPlacement:" in h
assert "readonly property var presentationPlacement:" in h
assert "function acceptPyramidTransaction(): void" in h
assert "function onTransactionGenerationChanged(): void" in h
assert "!root.coordinatedPyramidMotion && AbyssStyle.motionEnabled" in h
assert "finishClosing(" in h
assert "onBodyPlacementsChanged:" in c
assert "transitionCoordinator.syncResting(bodyPlacements,participants)" in c
print("pyramid phase-2 group reflow transaction contract: ok")
