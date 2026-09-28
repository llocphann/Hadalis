#!/usr/bin/env python3
from pathlib import Path
r=Path(__file__).resolve().parents[1]
x=(r/"modules/abyss/AbyssPopupTransitionCoordinator.qml").read_text()
h=(r/"modules/abyss/AbyssBodyHost.qml").read_text()
assert 'if (!identity || !(request?.pyramidStack ?? false))' in x
assert "onSemanticOpenChanged: if (initialized)" in h
block=h[h.index("onOpenChanged: if (initialized)"):h.index("onProgressChanged:",h.index("onOpenChanged: if (initialized)"))]
assert "syncTransitionSnapshot()" not in block
print("pyramid phase-2 semantic scope contract: ok")
