#!/usr/bin/env python3
from pathlib import Path

root = Path(__file__).resolve().parents[1]
cheatsheet = (root / "modules/cheatsheet/Cheatsheet.qml").read_text()
expand = (root / "modules/common/widgets/NavigationRailExpandButton.qml").read_text()

# Keybinds and Elements are two pages of one Cheatsheet surface, so focus-loss
# closing belongs to the shared host rather than either page.
for token in (
    "property bool _focusLossArmed: false",
    "readonly property var focusWindow: cheatsheetBackground.QsWindow.window",
    "function armFocusLoss(): void",
    "id: focusArmTimer",
    "target: NiriService",
    "function onActiveWindowChanged(): void",
    "CompositorFocusGrab {",
    "CompositorService.isHyprland && root.cheatsheetOpen",
    "onCleared: if (root.cheatsheetOpen) root.close()",
):
    assert token in cheatsheet, token

# The rail no longer carries a dedicated Close action; Escape/outside click and
# compositor focus loss remain the close mechanisms.
assert 'buttonIcon: "close"' not in cheatsheet
assert 'buttonText: Translation.tr("Close")' not in cheatsheet
assert "Qt.Key_Escape" in cheatsheet
assert "// Click outside to close" in cheatsheet

# The expand button stays at the collapsed-rail x position as the rail widens.
assert "Layout.alignment: Qt.AlignLeft" in expand
assert "Layout.leftMargin: 10" in expand
assert "Layout.alignment: Qt.AlignHCenter" not in expand

print("cheatsheet focus-close + fixed expand affordance contract: ok")
