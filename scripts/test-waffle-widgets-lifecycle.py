#!/usr/bin/env python3
"""Regression guard for Waffle widgets asynchronous presentation."""

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
WIDGETS = (ROOT / "modules/waffle/widgets/WaffleWidgets.qml").read_text()
HOST = (ROOT / "modules/waffle/ShellWafflePanelsImpl.qml").read_text()


def require(text: str, token: str, message: str) -> None:
    if token not in text:
        print(message)
        sys.exit(1)


def forbid(text: str, token: str, message: str) -> None:
    if token in text:
        print(message)
        sys.exit(1)


# The outer Waffle host is the only lifecycle loader for this heavyweight
# surface. It must remain asynchronous so first presentation is incubated
# between frames rather than completed in the click handler.
require(
    HOST,
    'OnDemandPanelLoader { identifier: "wWidgets"; open: GlobalStates.waffleWidgetsOpen',
    "Waffle widgets must remain owned by the on-demand host",
)
require(
    HOST,
    "activeAsync: enabledPanel && GlobalStates.deferredPanelsReady && resident",
    "Waffle on-demand panels must retain asynchronous activation",
)

# Do not reintroduce a nested synchronous Loader. Quickshell documents that
# active=true completes a LazyLoader synchronously and that nested loaders must
# explicitly support async loading; WidgetsContent is intentionally part of the
# outer incubated tree instead.
forbid(
    WIDGETS,
    "id: panelLoader",
    "Waffle widgets reintroduced the synchronous nested panel loader",
)
forbid(
    WIDGETS,
    "sourceComponent: PanelWindow",
    "Waffle widgets panel must not synchronously instantiate a nested PanelWindow",
)
require(
    WIDGETS,
    'WlrLayershell.namespace: "quickshell:wWidgets"',
    "Waffle widgets panel window is missing",
)
require(
    WIDGETS,
    "WlrLayershell.keyboardFocus: GlobalStates.waffleWidgetsOpen",
    "Waffle widgets keyboard grab must follow presentation state",
)
require(
    WIDGETS,
    "? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None",
    "Waffle widgets must release exclusive keyboard focus during close/unload",
)
require(
    WIDGETS,
    "if (!GlobalStates.waffleWidgetsOpen)\n                    content.close()",
    "Waffle widgets close animation contract is missing",
)

print("Waffle widgets lifecycle contract OK")
