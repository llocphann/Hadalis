#!/usr/bin/env python3
"""Regression contract for Niri-native focus/close lifecycle ownership."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise AssertionError(f"{label}: missing {needle!r}")


def reject(text: str, needle: str, label: str) -> None:
    if needle in text:
        raise AssertionError(f"{label}: stale compatibility lifecycle remains: {needle!r}")


def main() -> int:
    settings_focus = read("modules/settings/SettingsFocus.qml")
    settings_overlay = read("modules/settings/SettingsOverlay.qml")
    overlay = read("modules/ii/overlay/Overlay.qml")

    # Settings focus/close is Niri-native: layer-shell owns keyboard focus,
    # Escape unwinds the UI, and the full-output hit surface owns outside-close.
    for label, text in (
        ("SettingsFocus", settings_focus),
        ("SettingsOverlay", settings_overlay),
    ):
        require(text, "WlrKeyboardFocus.Exclusive", label)
        require(text, 'sequences: ["Escape"]', label)
        require(text, "MouseArea {", label)
        require(text, "GlobalStates.settingsOverlayOpen = false", label)
        reject(text, "CompositorFocusGrab {", label)
        reject(text, "id: grabTimer", label)
        reject(text, "grab.active =", label)

    # ii Overlay already derives keyboard ownership and input masking directly
    # from semantic state; the retired bridge/timer never supplied Niri behavior.
    require(overlay, "WlrKeyboardFocus.Exclusive", "Overlay")
    require(overlay, "mask: Region {", "Overlay")
    require(overlay, "OverlayContent {", "Overlay")
    reject(overlay, "CompositorFocusGrab {", "Overlay")
    reject(overlay, "id: delayedGrabTimer", "Overlay")
    reject(overlay, "grab.active =", "Overlay")

    print("Niri focus/close lifecycle contract: ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
