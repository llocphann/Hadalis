#!/usr/bin/env python3
from pathlib import Path
r=Path(__file__).resolve().parents[1]
apps=(r/"modules/dock/DockApps.qml").read_text()
btn=(r/"modules/dock/DockAppButton.qml").read_text()
dock=(r/"modules/abyss/content/AbyssDockContent.qml").read_text()
popup=(r/"modules/abyss/content/AbyssPopupContent.qml").read_text()
per=(r/"modules/abyss/AbyssPerimeter.qml").read_text()
gs=(r/"GlobalStates.qml").read_text()
menu=(r/"modules/abyss/content/AbyssDockAppMenuPopup.qml").read_text()
assert "readonly property real axisExtent:" in apps
assert "cacheBuffer: Math.max(256, root.axisExtent + 100)" in apps
assert "openAbyssContextMenu" in apps
assert "root.appListRoot?.openAbyssContextMenu(snapshot, root)" in btn
assert 'GlobalStates.abyssPopupKind = "dockAppMenu"' in dock
assert 'root.kind === "dockAppMenu" ? dockAppMenu' in popup
assert 'contentKind === "dockAppMenu"' in per
assert "property var abyssDockMenuModel: []" in gs
assert "GlobalStates.abyssDockMenuModel" in menu
# Dock application menus follow their longest visible action instead of
# reserving the historical 210/230 px fixed body width.
assert "implicitWidth: menuColumn.implicitWidth" in menu
assert "140, actionRow.implicitWidth + 20" in menu
assert "Math.max(210" not in menu
assert "Math.max(230" not in menu
print("Abyss Dock menu + stable axis extent + content-fit width contract: ok")
