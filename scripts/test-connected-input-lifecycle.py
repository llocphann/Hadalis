#!/usr/bin/env python3
"""Regression checks for connected popup pointer/focus lifecycle."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
failures = []


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def check(condition: bool, message: str) -> None:
    if not condition:
        failures.append(message)


def main() -> None:
    mask = read("modules/common/perimeter/ConnectedSurfaceMask.qml")
    popup = read("modules/bar/StyledPopup.qml")
    media = read("modules/bar/Media.qml")

    check("property bool inputEnabled: true" in mask,
          "ConnectedSurfaceMask must expose an explicit pointer-input policy")
    check("readonly property bool active: inputEnabled" in mask
          and "&& geometry?.valid === true" in mask,
          "ConnectedSurfaceMask activity must be gated by inputEnabled before geometry")
    check("inputEnabled: root.requestedVisible" in popup
          and "|| (root.hoverActivates && root._lingerVisible)" in popup,
          "StyledPopup must revoke click-popup input on close while preserving the hover bridge")
    check("mask: connectedMask" in popup,
          "StyledPopup must keep using the shaped connected-surface mask")
    check("enabled: root.active" in popup
          and "onHoveredChanged: root.popupHovered = hovered" in popup,
          "Hover popouts must retain the body hover bridge during visual linger")

    for token in (
        "property bool _niriFocusSeen: false",
        "onActiveChanged:",
        "CompositorService.isNiri",
        "popupWindow._niriFocusSeen = true",
        "root.requestClose()",
        "function onRequestedVisibleChanged()",
    ):
        check(token in popup,
              f"Focused connected popup must preserve Niri focus-loss lifecycle: {token}")
    check("if (!root.requestedVisible)" in popup
          and "popupWindow._niriFocusSeen = false" in popup,
          "Niri focus tracking must reset as soon as semantic popup state closes")
    check("if (!root.keyboardFocus || !CompositorService.isNiri)" in popup,
          "Niri focus-loss dismissal must be limited to keyboard-focused popups")

    check("hoverActivates: false" in media
          and "closeOnOutsideClick: true" in media
          and "keyboardFocus: true" in media,
          "Expanded Media must remain a click-activated focused popup covered by the input/focus policy")

    if failures:
        print("Connected popup input/focus lifecycle regression(s):")
        for failure in failures:
            print(f"  - {failure}")
        raise SystemExit(1)

    print("Connected popup input/focus lifecycle: OK")


if __name__ == "__main__":
    main()
