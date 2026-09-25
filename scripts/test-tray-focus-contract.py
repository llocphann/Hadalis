#!/usr/bin/env python3
"""Guard tray active-menu identity and Niri-native close/focus ownership."""

from pathlib import Path
import re

TRAY_PATH = Path("modules/bar/SysTray.qml")
TRAY_ITEM_PATH = Path("modules/bar/SysTrayItem.qml")
TRAY_MENU_PATH = Path("modules/bar/SysTrayMenu.qml")
CONTEXT_MENU_PATH = Path("modules/common/widgets/ContextMenu.qml")


def main() -> int:
    text = TRAY_PATH.read_text(encoding="utf-8")
    item_text = TRAY_ITEM_PATH.read_text(encoding="utf-8")
    tray_menu_text = TRAY_MENU_PATH.read_text(encoding="utf-8")
    context_menu_text = CONTEXT_MENU_PATH.read_text(encoding="utf-8")
    failures: list[str] = []

    required = (
        "root.activeMenu = window;",
        "function registerActiveMenu(window)",
        "function releaseActiveMenu(window)",
        "if (root.activeMenu === window)",
        "onMenuClosed: (qsWindow) => root.releaseActiveMenu(qsWindow);",
        "root.registerActiveMenu(qsWindow);",
        "if (root.activeMenu !== null)",
    )
    for needle in required:
        if needle not in text:
            failures.append(f"missing tray menu-tracking contract: {needle}")

    if "CompositorFocusGrab" in text:
        failures.append("SysTray must not allocate the retired compatibility focus bridge")
    if "overflowPopup.presentationWindow" in text:
        failures.append("SysTray must not retain presentation-window state solely for retired focus grabbing")
    if "setExtraWindowAndGrabFocus" in text or "releaseFocus(" in text:
        failures.append("SysTray must use compositor-neutral active-menu tracking names")

    for needle in (
        "signal menuClosed(qsWindow: var)",
        "const window = menu.item;",
        "root.menuClosed(window);",
    ):
        if needle not in item_text:
            failures.append(f"missing tray-item close identity contract: {needle}")

    for needle in (
        "StyledPopup {",
        "hoverTarget: root.anchorItem",
        "alternativeVisibleCondition: root.menuRequestedOpen",
        "closeOnOutsideClick: true",
        "keyboardFocus: root.keyboardMode",
        "root.menuOpened(presentationWindow)",
        "Qt.Key_Escape",
    ):
        if needle not in tray_menu_text:
            failures.append(f"missing connected tray-menu contract: {needle}")

    if "PopupWindow {" in tray_menu_text or "PanelWindow {" in tray_menu_text:
        failures.append("tray menu must not own a detached PopupWindow/PanelWindow presentation")
    if "anchorItem: root" not in item_text:
        failures.append("tray item must hand its real visual anchor to the connected menu")
    if "anchor {" in item_text[item_text.find("sourceComponent: SysTrayMenu {"):]:
        failures.append("tray item must not recreate compositor popup-anchor geometry")
    if "screen: popupWindow.screen" not in context_menu_text:
        failures.append("context-menu Niri backdrop must bind screen to the owning popup")

    release_match = re.search(
        r"function\s+releaseActiveMenu\s*\(\s*window\s*\)\s*\{(?P<body>.*?)\}",
        text,
        re.DOTALL,
    )
    if not release_match:
        failures.append("releaseActiveMenu(window) must remain identity-aware")
    else:
        body = release_match.group("body")
        if "root.activeMenu === window" not in body or "root.activeMenu = null;" not in body:
            failures.append("releaseActiveMenu(window) must clear only the matching activeMenu")

    if re.search(r"onMenuClosed\s*:\s*root\.releaseActiveMenu\s*\(\s*\)", text):
        failures.append("tray menu close handlers must forward the closing window identity")

    if failures:
        print("Tray/menu Niri lifecycle contract failures:")
        for failure in failures:
            print(f"  - {failure}")
        return 1

    print("Tray/menu Niri lifecycle contract: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
