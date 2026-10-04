#!/usr/bin/env python3
from pathlib import Path
r=Path(__file__).resolve().parents[1]
l=(r/"modules/abyss/content/AbyssLauncherControlsPopup.qml").read_text()
p=(r/"modules/abyss/looks/AbyssPresentation.js").read_text()
s=(r/"modules/abyss/settings/AbyssPositionSettings.qml").read_text()
a=(r/"modules/abyss/AbyssPerimeter.qml").read_text()
m=(r/"modules/abyss/content/AbyssDockAppMenuPopup.qml").read_text()
assert l.count("delegate: CompactChoice {") >= 2
assert 'labelText: Translation.tr(modelData.label)' in l
assert 'iconName: modelData.icon' in l
assert '"launcher"].concat(osds)' in p
assert '"launcher","dockAppMenu"' in p
assert 'Launcher presets' in s
presenter=(r/"modules/abyss/AbyssGenericPopupPresenter.qml").read_text()
assert 'placementPriority: root.activeKind === "dockAppMenu" ? -2 : 0' in presenter
assert 'colBackground: "transparent"' in m
assert "implicitHeight: 32" in m
print("launcher labels/join + Dock menu inward tray style contract: ok")
