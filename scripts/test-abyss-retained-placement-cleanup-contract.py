#!/usr/bin/env python3
from pathlib import Path
r=Path(__file__).resolve().parents[1]
b=(r/"modules/abyss/AbyssBodyHost.qml").read_text()
p=(r/"modules/abyss/AbyssPerimeter.qml").read_text()
assert "if (placementAvailable && placement.visible !== false)" in b
assert "window.closeGenericPopup()" in p
print("retained placement + generic cleanup contract: ok")
