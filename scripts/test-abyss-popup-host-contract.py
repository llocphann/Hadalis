#!/usr/bin/env python3
from pathlib import Path

r = Path(__file__).resolve().parents[1]
perimeter = (r / "modules/abyss/AbyssPerimeter.qml").read_text()
popup = (r / "modules/abyss/AbyssPopup.qml").read_text()
qmldir = (r / "modules/abyss/qmldir").read_text()

assert "AbyssPopup {" in perimeter
assert "requestedKind: GlobalStates.abyssPopupKind.length > 0" in perimeter
assert "joinedEdgeResolver:" in perimeter
assert "popup.overlapsRect(requestedRecord.surface, 10)" in perimeter
assert 'participantOverlapsRect("popup"' not in perimeter
assert "latchedContentKind" not in perimeter

assert '"launcher", "dockAppMenu", "wifi", "bluetooth", "audio", "media"' in popup
assert 'identity: "popup." + slot.kind' in popup
assert "semanticOpenOverride: slot.requestedVisible" in popup
assert "open: slot.lingerVisible" in popup
assert "externalProgress: slot.revealProgress" in popup
assert "animatePresentation: false" in popup
assert "placementCanResize: false" in popup
assert "contentKind: slot.kind" in popup
assert "Qt.callLater" in popup
assert "joinedEdge: root.joinedEdgeResolver" in popup
assert "AbyssPopup 1.0 AbyssPopup.qml" in qmldir

print("dedicated Abyss popup lifecycle contract: ok")
