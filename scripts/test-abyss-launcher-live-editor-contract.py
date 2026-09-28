#!/usr/bin/env python3
from pathlib import Path
r=Path(__file__).resolve().parents[1]
e=(r/"modules/abyss/AbyssEdgeEditor.qml").read_text()
l=(r/"modules/abyss/content/AbyssLauncherControlsPopup.qml").read_text()
assert '"utilities","launcher"' in e
assert "checkable: true" not in l
assert l.count("checked:") >= 2
print("launcher live-editor join contract: ok")
