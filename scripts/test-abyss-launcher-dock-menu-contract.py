#!/usr/bin/env python3
from pathlib import Path
r=Path(__file__).resolve().parents[1]
l=(r/"modules/abyss/content/AbyssLauncherControlsPopup.qml").read_text()
p=(r/"modules/abyss/looks/AbyssPresentation.js").read_text()
s=(r/"modules/abyss/settings/AbyssPositionSettings.qml").read_text()
a=(r/"modules/abyss/AbyssPerimeter.qml").read_text()
m=(r/"modules/abyss/content/AbyssDockAppMenuPopup.qml").read_text()
assert l.count("delegate: AbyssButton {") >= 2
assert 'text: Translation.tr(modelData.label)' in l
assert 'glyph: modelData.icon' in l
assert '"launcher"].concat(osds)' in p
assert '"launcher","dockAppMenu"' in p
assert 'Launcher presets' in s
assert 'placementPriority: contentKind === "dockAppMenu" ? -2 : 0' in a
assert 'colBackground: "transparent"' in m
assert "implicitHeight: 32" in m
print("launcher labels/join + Dock menu inward tray style contract: ok")
