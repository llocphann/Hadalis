#!/usr/bin/env python3
"""Static lifecycle guard for tooltip hover-source adapters.

This is deliberately not presented as Qt/Wayland interaction acceptance.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
tooltip = (ROOT / "modules/common/widgets/PopupToolTip.qml").read_text(
    encoding="utf-8"
)
alt_switcher = (
    ROOT / "modules/waffle/altSwitcher/WaffleAltSwitcherTile.qml"
).read_text(encoding="utf-8")
styled = (ROOT / "modules/common/widgets/StyledToolTip.qml").read_text(
    encoding="utf-8"
)
waffle = (ROOT / "modules/waffle/looks/WPopupToolTip.qml").read_text(
    encoding="utf-8"
)


def require(source: str, clause: str, message: str) -> None:
    if clause not in source:
        raise SystemExit("FAIL: " + message)


for clause in (
    "parent.visualFocus",
    "parent.focusReason === Qt.TabFocusReason",
    "parent.focusReason === Qt.BacktabFocusReason",
    "parent.focusReason === Qt.ShortcutFocusReason",
    "return false",
    "property bool externalHoverState: root.extraVisibleCondition",
    "property bool externalPressedState: false",
    "return root.externalHoverState",
    "if (root.externalPressedState)",
    "root.suppressUntilHoverExit = root.parentHoverState",
    "onParentHoverStateChanged:",
    "root.suppressUntilHoverExit = false",
    "&& !root.suppressUntilHoverExit && !root.parentPressedState",
    "parent ? parent.visible : false",
    "onInternalVisibleConditionChanged:",
    "onVisibleChanged:",
    "onParentChanged:",
    "_showDelayTimer.stop()",
    "if (root.visible && root.internalVisibleCondition)",
):
    require(tooltip, clause, "shared tooltip lifecycle guard missing: " + clause)

require(
    tooltip,
    "return false\n    }\n    readonly property bool parentPressedState:",
    "unknown parent hover must be false, not implicitly true",
)
require(
    tooltip,
    "active: root.visible && root.internalVisibleCondition",
    "tooltip presentation Loader active state must not depend on window association",
)
require(
    tooltip,
    "sourceComponent: root._canUsePopupWindow",
    "tooltip presentation path must switch by source component",
)
require(tooltip, "id: popupWindowPresentation",
        "PopupWindow presentation path missing")
require(tooltip, "id: fallbackItemPresentation",
        "ApplicationWindow fallback presentation path missing")
require(tooltip, "onLoaded:",
        "deferred reveal must restart after presentation reparenting")
for forbidden in (
    "active: root._canUsePopupWindow &&",
    "active: !root._canUsePopupWindow &&",
    "id: fallbackLoader",
):
    if forbidden in tooltip:
        raise SystemExit(
            "FAIL: tooltip retained split Loader activity binding: " + forbidden
        )

for clause in (
    "useParentHover: false",
    "externalHoverState: compactMouse.containsMouse",
    "externalPressedState: compactMouse.pressed",
    "extraVisibleCondition: !root.selected",
):
    require(alt_switcher, clause, "Waffle compact tooltip missing: " + clause)

for name, implementation in (("StyledToolTip", styled), ("WPopupToolTip", waffle)):
    require(implementation, "PopupToolTip {", name + " must share tooltip lifecycle")

print("ok - shared tooltip hover, click, and deferred-show lifecycle contract")
