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
assert "function _publishClosings(next): void" in coord
assert "root.closings=next" in coord
assert "root.revision += 1" in coord
assert "property var closings: ({})" in coord
assert "property var frozenPlacements: ({})" not in coord
assert "function _pyramidDescriptorsRelated(a,b): bool" in coord
assert "function _pyramidGroupCandidates(identity, request," in coord
assert "root._descriptorGap(a,b)" in coord
assert "tangentStart" in coord and "tangentEnd" in coord
assert "stackProximity:root.stackProximity" in host

# The closing popup keeps its own snapshot, while semantic survivors consume
# live allocator targets immediately and start their reflow in the same frame.
assert "return transaction?.placement ?? livePlacement ?? null" in coord
assert "frozen[peer.identity]" not in coord
assert "_rebuildFrozen" not in coord
assert "function cancelClose(identity): void" in coord
assert "function finishClose(identity): void" in coord
assert "function beginReopen(identity): void" in coord
assert "function resumeClose(identity): void" in coord
assert "function finishReopen(identity): void" in coord
assert "function resetIdentity(identity): void" in coord
assert host.count("root.pyramidMotionEnabled") >= 5
assert host.count("Easing.InOutCubic") >= 4

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
assert "function finishPyramidCloseIfDone(): void" in host
assert "root.finishPyramidCloseIfDone()" in host
assert "function finishPyramidReopenIfDone(): void" in host
assert "root.finishPyramidReopenIfDone()" in host
assert "onProgressChanged: {" in host
assert "const liveRecord=" in coord
assert "liveRecord ?? closing.fullRecord" in coord
assert "property bool pyramidReopening: false" in host
assert "root.pyramidCoordinator?.beginReopen(root.identity)" in host
assert "root.pyramidCoordinator?.resumeClose(root.identity)" in host
assert "root.pyramidCoordinator?.finishReopen(root.identity)" in host
assert "participant.geometry" in coord
assert "participant.restingRecord" in coord
assert "Geometry.joinCorner(" in host
assert "rawPresentationRecord,joinedEdge" in host
assert "result.along=_number(to.along,0)" in motion
assert "result.span=Math.max(0,_number(to.span,0))" in motion
assert "elasticFilled:placement.elasticFilled === true" in motion
assert "elasticLimits:placement.elasticLimits === true" in motion

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

# Static same-neighborhood order stays in allocator; old close-only geometry hacks stay out.
assert 'a?.stackPolicy === "pyramid"' in placement
assert "function _samePyramidNeighborhood(a,b)" in placement
for forbidden in ("closeInward","pyramidCloseInward","pyramidCloseTarget"):
    assert forbidden not in geometry
    assert forbidden not in host
    assert forbidden not in ctrl

print("Pyramid Popup v2 motion contract: ok")
