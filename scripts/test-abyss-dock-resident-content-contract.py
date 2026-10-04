#!/usr/bin/env python3
from pathlib import Path
root=Path(__file__).resolve().parents[1]
host=(root/"modules/abyss/AbyssBodyHost.qml").read_text()
perim=(root/"modules/abyss/AbyssPerimeter.qml").read_text()
assert "property bool residentContent: false" in host
assert "(root.residentContent || root.visualResident)" in host
dock=perim[perim.index("id: dock"):perim.index("Item {", perim.index("id: dock"))]
assert "residentContent: true" in dock
assert "contentItem.item?.requestDockShow" in dock
assert "attachedPopupHold" in dock
assert "liquid.hasPopupAnchoredTo(dock)" in dock
assert dock.count("|| attachedPopupHold") >= 3
ctrl=(root/"modules/abyss/AbyssSurfaceController.qml").read_text()
assert "function hasPopupAnchoredTo(anchor): bool" in ctrl
assert "entry.popup?._liquidAnchor === anchor" in ctrl
print("abyss dock resident-content + attached-popup hold contract: ok")
