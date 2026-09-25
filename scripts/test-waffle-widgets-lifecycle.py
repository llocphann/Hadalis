#!/usr/bin/env python3
"""Regression guard for Waffle heavyweight panel presentation."""

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
WIDGETS = (ROOT / "modules/waffle/widgets/WaffleWidgets.qml").read_text()
START = (ROOT / "modules/waffle/startMenu/WaffleStartMenu.qml").read_text()
ACTION = (ROOT / "modules/waffle/actionCenter/WaffleActionCenter.qml").read_text()
NOTIFICATIONS = (
    ROOT / "modules/waffle/notificationCenter/WaffleNotificationCenter.qml"
).read_text()
HOST = (ROOT / "modules/waffle/ShellWafflePanelsImpl.qml").read_text()


def require(text: str, token: str, message: str) -> None:
    if token not in text:
        print(message)
        sys.exit(1)


def forbid(text: str, token: str, message: str) -> None:
    if token in text:
        print(message)
        sys.exit(1)


# The outer Waffle host is the only lifecycle loader for heavyweight surfaces.
# It must remain asynchronous so first presentation is incubated between frames
# rather than completed in a button/key handler.
for panel_id, state in (
    ("wStartMenu", "GlobalStates.searchOpen"),
    ("wWidgets", "GlobalStates.waffleWidgetsOpen"),
):
    require(
        HOST,
        f'OnDemandPanelLoader {{ identifier: "{panel_id}"; open: {state}',
        f"{panel_id} must remain owned by the on-demand host",
    )
require(
    HOST,
    "activeAsync: enabledPanel && GlobalStates.deferredPanelsReady && resident",
    "Waffle on-demand panels must retain asynchronous activation",
)

# Quickshell documents that active=true completes a loader synchronously and
# that nested component loading must explicitly support async incubation.
# Start and Widgets are already inside the outer LazyLoader, so their heavy
# window/content trees must stay direct children of that asynchronous tree.
for name, text in (("start menu", START), ("widgets", WIDGETS)):
    forbid(
        text,
        "id: panelLoader",
        f"Waffle {name} reintroduced a synchronous nested panel loader",
    )
    forbid(
        text,
        "sourceComponent: PanelWindow",
        f"Waffle {name} must not synchronously instantiate a nested PanelWindow",
    )

require(
    START,
    "presented: GlobalStates.searchOpen",
    "Waffle start menu must drive retained content through presented state",
)
require(
    START,
    "WlrLayershell.keyboardFocus: GlobalStates.searchOpen",
    "Waffle start menu keyboard grab must follow presentation state",
)
require(
    WIDGETS,
    "presented: GlobalStates.waffleWidgetsOpen",
    "Waffle widgets must drive content through presented state",
)
require(
    WIDGETS,
    "WlrLayershell.keyboardFocus: GlobalStates.waffleWidgetsOpen",
    "Waffle widgets keyboard grab must follow presentation state",
)
for name, text in (("start menu", START), ("widgets", WIDGETS)):
    require(
        text,
        "? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None",
        f"Waffle {name} must release exclusive keyboard focus while closing",
    )

# When multi-panel mode is disabled, every keyboard-exclusive Waffle surface
# must also evict Widgets. Otherwise two layer-shell surfaces can hold competing
# exclusive keyboard grabs at once.
for name, text in (
    ("start menu", START),
    ("action center", ACTION),
    ("notification center", NOTIFICATIONS),
):
    require(
        text,
        "GlobalStates.waffleWidgetsOpen = false",
        f"Waffle {name} no longer closes Widgets in exclusive-panel mode",
    )
for token in (
    "GlobalStates.searchOpen = false",
    "GlobalStates.waffleActionCenterOpen = false",
    "GlobalStates.waffleNotificationCenterOpen = false",
):
    require(
        WIDGETS,
        token,
        "Waffle Widgets no longer closes the other exclusive panels",
    )

print("Waffle heavyweight panel lifecycle contract OK")
