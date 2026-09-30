#!/usr/bin/env python3
from pathlib import Path
r=Path(__file__).resolve().parents[1]
p=(r/"modules/abyss/AbyssPerimeter.qml").read_text()
d=(r/"modules/abyss/content/AbyssDockContent.qml").read_text()
b=(r/"modules/dock/DockAppButton.qml").read_text()
assert p.count('GlobalStates.abyssPopupKind === "dockAppMenu"') >= 2
assert "function closeAppMenu(): void" in d
assert "onEdgeChanged: root.closeAppMenu()" in d
assert "Component.onDestruction: root.closeAppMenu()" in d
assert "setAbyssContextMenuHover(root, false)" in b
print("attached Dock menu lifecycle contract: ok")
