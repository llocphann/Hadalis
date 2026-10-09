#!/usr/bin/env python3
"""Desktop context menus are click-driven, not auto-dismissing hover previews.

Bare desktop gaps exposed by Abyss "Width affects modules = OFF" can
intersect an animated popup. Do not close the menu when the pointer leaves
its transient animated bounds. Other per-module ContextMenu users retain
their own hover-close behavior.
"""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
menu = (root / "modules/common/widgets/ContextMenu.qml").read_text()
desktop = (root / "modules/background/Background.qml").read_text()

# The shared hover timer still exists for hover-triggered menus, but the
# desktop and desktop-item context menus must explicitly opt out.
bare = desktop.split("id: desktopContextMenu", 1)[1].split("model:", 1)[0]
managed = desktop.split("id: desktopItemContextMenu", 1)[1].split("WidgetCanvas {", 1)[0]
for label, block in (("bare desktop", bare), ("desktop item", managed)):
    assert "closeOnHoverLost: false" in block, label
    assert "closeOnFocusLost: false" in block, label
    assert "closeOnHoverLost: true" not in block, label

assert "running: root.closeOnHoverLost" in menu
assert "property bool closeOnHoverLost: true" in menu
assert "property bool entranceSettled: false" in menu
assert "if (hovered && popupWindow.entranceSettled)" in menu
assert "acceptedButtons: Qt.RightButton | Qt.LeftButton" in desktop
assert "if (desktopContextMenu.active) desktopContextMenu.close()" in desktop
assert "if (desktopItemContextMenu.active) desktopItemContextMenu.close()" in desktop
assert "Keys.onPressed: event => {" in menu
assert "event.key === Qt.Key_Escape" in menu
assert "root.close();" in menu

print("PASS: desktop context menus persist until explicit dismissal")
