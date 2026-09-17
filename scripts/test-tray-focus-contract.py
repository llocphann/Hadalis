#!/usr/bin/env python3
"""Guard tray focus-grab state and Niri menu output ownership."""

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
        "overflowPopup.presentationWindow",
        "root.activeMenu = window;",
        "active: (root.trayOverflowOpen && overflowPopup.presentationWindow !== null)",
        ".filter(window => window !== null)",
        "function releaseFocus(window)",
        "if (root.activeMenu === window)",
        "onMenuClosed: (qsWindow) => root.releaseFocus(qsWindow);",
    )
    for needle in required:
        if needle not in text:
            failures.append(f"missing tray focus contract: {needle}")

    item_required = (
        "signal menuClosed(qsWindow: var)",
        "const window = menu.item;",
        "root.menuClosed(window);",
    )
    for needle in item_required:
        if needle not in item_text:
            failures.append(f"missing tray-item close identity contract: {needle}")

    # Full-output Niri click catchers must stay on the same output as the popup.
    # Leaving PanelWindow.screen null lets the compositor choose an output, which
    # can put the backdrop on the wrong monitor in multi-output sessions.
    if "screen: root.screen" not in tray_menu_text:
        failures.append("tray Niri backdrop must bind screen to the owning popup")
    if "screen: popupWindow.screen" not in context_menu_text:
        failures.append("context-menu Niri backdrop must bind screen to the owning popup")

    # QML imperative assignment to a bound property removes that binding. The
    # focus-grab active state must therefore remain derived from popup/menu state.
    if re.search(r"\bfocusGrab\.active\s*=", text):
        failures.append("focusGrab.active must stay declarative; imperative assignment breaks its binding")

    release_match = re.search(
        r"function\s+releaseFocus\s*\(\s*window\s*\)\s*\{(?P<body>.*?)\}",
        text,
        re.DOTALL,
    )
    if not release_match:
        failures.append("releaseFocus(window) must remain identity-aware")
    else:
        body = release_match.group("body")
        if "root.activeMenu === window" not in body or "root.activeMenu = null;" not in body:
            failures.append("releaseFocus(window) must clear only the matching activeMenu")

    if re.search(r"onMenuClosed\s*:\s*root\.releaseFocus\s*\(\s*\)", text):
        failures.append("tray menu close handlers must forward the closing window identity")

    if failures:
        print("Tray/menu focus-output contract failures:")
        for failure in failures:
            print(f"  - {failure}")
        return 1

    print("Tray/menu focus-output contract: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
