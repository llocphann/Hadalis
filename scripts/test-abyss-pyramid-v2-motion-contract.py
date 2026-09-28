#!/usr/bin/env python3
from pathlib import Path

r=Path(__file__).resolve().parents[1]
host=(r/"modules/abyss/AbyssBodyHost.qml").read_text()
ctrl=(r/"modules/abyss/AbyssSurfaceController.qml").read_text()
coord=(r/"modules/abyss/AbyssPyramidCoordinator.qml").read_text()
motion=(r/"modules/abyss/looks/AbyssPyramidMotion.js").read_text()
geometry=(r/"modules/abyss/looks/AbyssGeometry.js").read_text()
placement=(r/"modules/abyss/looks/AbyssBodyPlacement.js").read_text()
per=(r/"modules/abyss/AbyssPerimeter.qml").read_text()
generic=(r/"modules/abyss/AbyssGenericPopupPresenter.qml").read_text()
styled=(r/"modules/bar/StyledPopup.qml").read_text()

# Resting layout and visual lifecycle stay separate.
assert "readonly property AbyssPyramidCoordinator pyramidCoordinator" in ctrl
assert "function beginClose(identity, request, placement, fullRecord)" in coord
assert "function entryOrigin(identity, request, placement, fullRecord)" in coord
assert "function targetFor(identity, livePlacement)" in coord
assert "property var closings: ({})" in coord
assert "property var frozenPlacements: ({})" in coord
assert "root._sameAnchorDescriptor(" in coord
assert "Math.abs(root._number(a.anchorCenter)" in coord

# Closing freezes only its same-anchor peer group; finish/cancel releases it.
assert "frozen[peer.identity]" in coord
assert "function cancelClose(identity): void" in coord
assert "function finishClose(identity): void" in coord
assert "function resetIdentity(identity): void" in coord

# Presentation records use snapshot interpolation, then Join Edge is applied.
assert 'import "looks/AbyssPyramidMotion.js" as PyramidMotion' in host
assert "PyramidMotion.interpolateRecord(" in host
assert "PyramidMotion.collapsedRecord(" in host
assert "property var pyramidLastPlacement: null" in host
assert "property var pyramidLastFullRecord: null" in host
assert "const closingPlacement=root.pyramidLastPlacement" in host
assert "const closingRecord=root.pyramidLastFullRecord" in host
assert "readonly property var pyramidAllocatorPlacement:" in host
assert "readonly property var pyramidAllocatorRecord:" in host
assert "root.pyramidAllocatorPlacement,root.pyramidAllocatorRecord" in host
assert "Qt.callLater(root.syncPyramidEntryOrigin)" not in host
assert "root.pyramidOriginRecord && root.progress > 0.001" in host
assert "const liveRecord=" in coord
assert "liveRecord ?? closing.fullRecord" in coord
assert "Geometry.joinCorner(" in host
assert "rawPresentationRecord,joinedEdge" in host
assert "result.along=_number(to.along,0)" in motion
assert "result.span=Math.max(0,_number(to.span,0))" in motion

# Content is slide-under clipped at fixed size: no pyramid fade/shrink.
assert "id: contentCanvas" in host
assert "root.pyramidPresentationActive" in host
assert "? 1 : Math.min(1,root.progress*1.5)" in host
assert "parent: contentCanvas" in host

# Input ends at semantic close, while visual open/linger may continue.
assert "root.semanticOpen && root.placementVisible" in host
assert "root.open || root.progress > 0.001" in host
assert "liquidSemanticVisible" in styled
assert "root.requestedVisible || root._liquidSemanticHold" in styled
assert "root._liquidSemanticHold = true" in styled
assert "root._liquidSemanticHold = false" in styled

# Only popup hosts opt into pyramid motion.
assert 'stackPolicy: "pyramid"' in generic
assert 'stackPolicy: "pyramid"' in per
assert "semanticOpenOverride:" in generic
assert "hostedPopup?.liquidSemanticVisible ?? false" in per

# Static same-anchor order stays in allocator; old close-only geometry hacks stay out.
assert 'a?.stackPolicy === "pyramid"' in placement
for forbidden in ("closeInward","pyramidCloseInward","pyramidCloseTarget"):
    assert forbidden not in geometry
    assert forbidden not in host
    assert forbidden not in ctrl

print("Pyramid Popup v2 motion contract: ok")
