#!/usr/bin/env python3
from pathlib import Path

r=Path(__file__).resolve().parents[1]
per=(r/"modules/abyss/AbyssPerimeter.qml").read_text()
styled=(r/"modules/bar/StyledPopup.qml").read_text()
global_states=(r/"GlobalStates.qml").read_text()
classic=(r/"modules/bar/Bar.qml").read_text()
vertical=(r/"modules/verticalBar/VerticalBar.qml").read_text()

# StyledPopup owns a per-output lease for the full visible/retract lifecycle.
assert "property bool barAutoHideHoldEnabled: true" in styled
assert "GlobalStates.setBarPopupHoverLease(" in styled
assert "root.presentationActive && root._anchorReady" in styled
assert "function barPopupHoverHeld(outputName: string): bool" in global_states

# Classic and Abyss bars must consume the same lease contract.
assert "GlobalStates.barPopupHoverHeld(barRoot.outputName)" in classic
assert "GlobalStates.barPopupHoverHeld(barRoot.outputName)" in vertical
bar_policy=per[per.index("function barOnOutput"):per.index("function outputInsets")]
assert "GlobalStates.barPopupHoverHeld(name)" in bar_policy

# The transient hover latch must be allowed to clear while a popup lease holds
# the Bar. Otherwise the timer fires once during popup lifetime, does nothing,
# and leaves the Bar permanently revealed after the popup retracts.
timer=per[per.index("id: barClose"):per.index("property real barProgress")]
assert "!barHover.hovered && !revealHover.hovered" in timer
assert "!liquid.popupsOpen" not in timer
assert "!popup.open" not in timer
assert "root.setBarRevealed(window.outputName,false)" in timer

print("Abyss Bar auto-hide popup lease contract: ok")
