#!/usr/bin/env python3
from pathlib import Path

r = Path(__file__).resolve().parents[1]
host = (r / "modules/abyss/AbyssBodyHost.qml").read_text()
ctrl = (r / "modules/abyss/AbyssSurfaceController.qml").read_text()
coord = (r / "modules/abyss/AbyssPopupTransitionCoordinator.qml").read_text()
launcher = (r / "modules/abyss/content/AbyssLauncherControlsPopup.qml").read_text()

assert "property var semanticOpenOverride: undefined" in host
assert "readonly property bool semanticOpen:" in host
assert "readonly property bool visualResident:" in host
assert "root.semanticOpen && root.placementVisible" in host
assert "open:root.semanticOpen" in host
assert "(root.residentContent || root.visualResident)" in host
assert "property QtObject transitionCoordinator: AbyssPopupTransitionCoordinator" in ctrl
assert "property bool motionEnabled: true" in coord
assert "function planClose(identity): var" in coord
assert "function observeSemantic(identity,open,request,placement,record): void" in coord
assert 'heading: Translation.tr("Surface Performance")' in launcher
assert 'heading: Translation.tr("Wave Preset")' in launcher
assert "component PopupChoice: AbstractButton" in launcher
assert "AbyssButton" not in launcher
print("pyramid lifecycle + rebuilt Launcher labels contract: ok")
