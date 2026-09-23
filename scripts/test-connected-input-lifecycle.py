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
    mask = read("modules/common/perimeter/ConnectedSurfaceBodyMask.qml")
    legacy_mask = read("modules/common/perimeter/ConnectedSurfaceMask.qml")
    popup = read("modules/bar/StyledPopup.qml")
    media = read("modules/bar/Media.qml")

    check("property bool inputEnabled: true" in mask,
          "ConnectedSurfaceBodyMask must expose an explicit pointer-input policy")
    check("readonly property bool active: root.inputEnabled" in mask
          and "&& root.geometry?.valid === true" in mask,
          "ConnectedSurfaceBodyMask activity must be gated by inputEnabled before geometry")
    check("property rect visibleBodyRect:" in mask
          and "_sourceStrip" not in mask
          and "_middleStrip" not in mask
          and "_bodyStrip" not in mask
          and "connectorItem" not in mask,
          "ii popup input must stay body-only with no retired connector-strip approximation")
    check("_sourceStrip" in legacy_mask and "_bodyStrip" in legacy_mask,
          "legacy connected mask must remain available for Waffle/non-cutover surfaces")
    check("inputEnabled: root.requestedVisible" in popup
          and "|| (root.hoverActivates && root._lingerVisible)" in popup,
          "StyledPopup must revoke click-popup input on close while preserving the hover bridge")
    check("ConnectedSurfaceBodyMask {" in popup
          and "visibleBodyRect: frame.visibleBodyRect" in popup
          and "mask: connectedMask" in popup,
          "StyledPopup must use the owner-clipped body-only compositor mask")
    check("readonly property bool popupHovered: root._bodyHovered || root._contentHovered" in popup
          and "onBodyHoveredChanged: root._bodyHovered = bodyHovered" in popup
          and "enabled: root.active" in popup
          and "onHoveredChanged: root._contentHovered = hovered" in popup,
          "Hover popouts must retain hover across both the body and interactive content plane")

    for token in (
        "focusable: root.keyboardFocus && root.requestedVisible",
        "property bool exclusiveKeyboardFocus: false",
        "WlrLayershell.keyboardFocus: root.keyboardFocus && root.requestedVisible",
        "? WlrKeyboardFocus.Exclusive",
        ": WlrKeyboardFocus.OnDemand",
        ": WlrKeyboardFocus.None",
        "CompositorFocusGrab {",
        "active: root.keyboardFocus && root.requestedVisible",
        "windows: [popupWindow]",
        "onCleared: root.requestClose()",
    ):
        check(token in popup,
              f"Focused connected popup must preserve the layer-shell/focus-grab lifecycle: {token}")

    for forbidden in (
        "onActiveChanged:",
        "property bool _niriFocusSeen",
        "popupWindow._niriFocusSeen",
        "CompositorService.isNiri",
    ):
        check(forbidden not in popup,
              f"StyledPopup must not revive the retired PanelWindow active-focus workaround: {forbidden}")

    check("visible: root._anchorReady && root.requestedVisible && root.closeOnOutsideClick" in popup
          and "screen: root._anchorScreen" in popup,
          "Outside-click catcher must follow semantic visibility and explicit source-screen ownership")

    check("hoverActivates: true" in media
          and "closeOnOutsideClick: root.barMediaPopupVisible" in media
          and "keyboardFocus: root.barMediaPopupVisible" in media,
          "Media must open on hover while reserving outside-click and keyboard focus for explicit pinning")

    if failures:
        print("Connected popup input/focus lifecycle regression(s):")
        for failure in failures:
            print(f"  - {failure}")
        raise SystemExit(1)

    print("Connected popup input/focus lifecycle: OK")


if __name__ == "__main__":
    main()
