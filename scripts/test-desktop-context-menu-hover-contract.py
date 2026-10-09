#!/usr/bin/env python3
"""Guard deferred hover-exit arming for animated desktop context menus.

The first popup animation may carry the body under a stationary cursor.
That transition must not arm the 700ms close-on-hover-lost timer, or a
right-click in transparent, retracted Abyss edge gaps will flicker.
Native Niri desktop interaction must still be qualified separately.
"""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
menu = (root / "modules/common/widgets/ContextMenu.qml").read_text()
desktop = (root / "modules/background/Background.qml").read_text()
assert "property bool entranceSettled: false" in menu
assert "if (popupWindow.closing) return" in menu
assert "popupWindow.entranceSettled = true" in menu
assert "if (popupWindow.popupContainsMouse)" in menu
assert "if (hovered && popupWindow.entranceSettled)" in menu
assert "&& (!root.closeOnHoverLostAfterEntered || popupWindow.popupWasHovered)" in menu
assert "closeOnHoverLostAfterEntered: true" in desktop
assert "closeOnHoverLostDelay: 700" in desktop
assert "if (desktopContextMenu.active) desktopContextMenu.close()" in desktop
assert "Keys.onPressed: event => {" in menu
print("PASS: desktop context menu hover loss arms only on settled visit")
