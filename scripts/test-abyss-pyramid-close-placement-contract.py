#!/usr/bin/env python3
from pathlib import Path
t=(Path(__file__).resolve().parents[1]/"modules/abyss/AbyssBodyHost.qml").read_text()
assert "readonly property bool placementAvailable:" in t
assert "placementAvailable && placement.visible !== false" in t
assert "(retainedPlacement ?? placement)" in t
assert "pyramid child retreats through the" in t
print("abyss retained pyramid close placement contract: ok")
