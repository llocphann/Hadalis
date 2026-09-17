#!/usr/bin/env python3
"""Guard tray focus-grab state for connected popouts and context menus."""

from pathlib import Path
import re

TRAY_PATH = Path("modules/bar/SysTray.qml")


def main() -> int:
    text = TRAY_PATH.read_text(encoding="utf-8")
    failures: list[str] = []

    required = (
        "overflowPopup.presentationWindow",
        "root.activeMenu = window;",
        "root.activeMenu = null;",
        "active: (root.trayOverflowOpen && overflowPopup.presentationWindow !== null)",
        ".filter(window => window !== null)",
    )
    for needle in required:
        if needle not in text:
            failures.append(f"missing tray focus contract: {needle}")

    # QML imperative assignment to a bound property removes that binding. The
    # focus-grab active state must therefore remain derived from popup/menu state.
    if re.search(r"\bfocusGrab\.active\s*=", text):
        failures.append("focusGrab.active must stay declarative; imperative assignment breaks its binding")

    release_match = re.search(
        r"function\s+releaseFocus\s*\(\s*\)\s*\{(?P<body>.*?)\}",
        text,
        re.DOTALL,
    )
    if not release_match or "root.activeMenu = null;" not in release_match.group("body"):
        failures.append("releaseFocus() must clear activeMenu so the declarative grab can release")

    if failures:
        print("Tray focus contract failures:")
        for failure in failures:
            print(f"  - {failure}")
        return 1

    print("Tray focus contract: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
