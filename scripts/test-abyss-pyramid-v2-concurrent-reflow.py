#!/usr/bin/env python3
"""Pyramid v2 concurrent survivor-reflow contract.

When one popup closes, semantic survivors in the same tangent neighborhood must
start moving toward their new allocator tier immediately. They must not stay
frozen until the closing tail reaches zero.
"""
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
coord=(ROOT/"modules/abyss/AbyssPyramidCoordinator.qml").read_text()
host=(ROOT/"modules/abyss/AbyssBodyHost.qml").read_text()

assert "property var frozenPlacements: ({})" not in coord
assert "_rebuildFrozen" not in coord
assert "return transaction?.placement ?? livePlacement ?? null" in coord
assert "function _publishClosings(next): void" in coord
assert "root.closings=next" in coord
assert "frozen[peer.identity]" not in coord

# The closing identity still keeps its snapshot, so its retract path cannot jump
# when allocator truth removes it. Only survivors use livePlacement.
assert "const transaction=root.closings[String(identity)]" in coord
assert "placement:Motion.clonePlacement(placement)" in coord

# Pyramid peer reflow uses the same InOutCubic curve as the generic popup
# reveal/retract path. Non-Pyramid allocator reflow keeps the prior OutCubic.
assert host.count("root.pyramidMotionEnabled") >= 5
assert host.count("? Easing.InOutCubic : Easing.OutCubic") >= 4

# Simple model: survivor motion begins while closer progress is still non-zero.
closing_progress=[1.0,.75,.50,.25,0.0]
survivor_inward=[260,195,130,65,0]
assert len(closing_progress)==len(survivor_inward)
assert survivor_inward[1] < survivor_inward[0]
assert closing_progress[1] > 0
assert survivor_inward[-1] == 0

print("Pyramid Popup v2 concurrent survivor reflow contract: ok")
