#!/usr/bin/env python3
from pathlib import Path
r=Path(__file__).resolve().parents[1]
host=(r/"modules/abyss/AbyssBodyHost.qml").read_text()
ctrl=(r/"modules/abyss/AbyssSurfaceController.qml").read_text()
coord=(r/"modules/abyss/AbyssPopupTransitionCoordinator.qml").read_text()
launcher=(r/"modules/abyss/content/AbyssLauncherControlsPopup.qml").read_text()

assert "readonly property bool semanticOpen: root.open" in host
assert "readonly property bool visualResident:" in host
assert "readonly property bool acceptsInput: root.presented" in host
assert "open:root.semanticOpen" in host
assert "(root.residentContent || root.visualResident)" in host
assert "property QtObject transitionCoordinator: AbyssPopupTransitionCoordinator" in ctrl
assert "property bool motionEnabled: false" in coord
assert "function planClose(identity): var" in coord
assert "function observeSemantic(identity,open,request,placement,record): void" in coord
assert 'heading: Translation.tr("Wave Mode")' in launcher
assert 'heading: Translation.tr("Wave Preset")' in launcher
assert launcher.count("compact: false") >= 2
assert "Layout.minimumWidth: 180" in launcher
assert "Layout.minimumWidth: 110" in launcher
print("pyramid transition phase-1 + Launcher labels contract: ok")
