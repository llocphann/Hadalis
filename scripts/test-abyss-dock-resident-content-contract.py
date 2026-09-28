#!/usr/bin/env python3
from pathlib import Path
root=Path(__file__).resolve().parents[1]
host=(root/"modules/abyss/AbyssBodyHost.qml").read_text()
perim=(root/"modules/abyss/AbyssPerimeter.qml").read_text()
assert "property bool residentContent: false" in host
assert "(root.residentContent || root.open || root.progress > 0.001)" in host
dock=perim[perim.index("id: dock"):perim.index("Item {", perim.index("id: dock"))]
assert "residentContent: true" in dock
assert "contentItem.item?.requestDockShow" in dock
print("abyss dock resident-content binding contract: ok")
