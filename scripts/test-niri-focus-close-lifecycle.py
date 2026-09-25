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

    # Shared and long-lived shell surfaces must not allocate a dead focus bridge.
    # Each one already owns its Niri focus and close behavior explicitly.
    native_surfaces = {
        "StyledPopup": read("modules/bar/StyledPopup.qml"),
        "ContextMenu": read("modules/common/widgets/ContextMenu.qml"),
        "ControlPanel": read("modules/controlPanel/ControlPanel.qml"),
        "Dashboard": read("modules/dashboard/Dashboard.qml"),
        "SidebarHost": read("modules/sidebar/SidebarHost.qml"),
        "WaffleBarPopup": read("modules/waffle/bar/BarPopup.qml"),
    }
    for label, text in native_surfaces.items():
        reject(text, "CompositorFocusGrab {", label)

    require(native_surfaces["StyledPopup"], "id: clickOutsideBackdrop", "StyledPopup")
    require(native_surfaces["StyledPopup"], "WlrKeyboardFocus.OnDemand", "StyledPopup")
    require(native_surfaces["ContextMenu"], "id: clickOutsideBackdrop", "ContextMenu")
    require(native_surfaces["ContextMenu"], "Qt.Key_Escape", "ContextMenu")
    require(native_surfaces["ControlPanel"], "WlrKeyboardFocus.Exclusive", "ControlPanel")
    require(native_surfaces["ControlPanel"], "Qt.Key_Escape", "ControlPanel")
    require(native_surfaces["Dashboard"], "mask: dashboardInputRegion", "Dashboard")
    require(native_surfaces["Dashboard"], "Qt.Key_Escape", "Dashboard")
    require(native_surfaces["SidebarHost"], "WlrKeyboardFocus.Exclusive", "SidebarHost")
    require(native_surfaces["SidebarHost"], "Qt.Key_Escape", "SidebarHost")
    require(native_surfaces["WaffleBarPopup"], "StandardKey.Cancel", "WaffleBarPopup")
    require(native_surfaces["WaffleBarPopup"], "id: clickOutsideBackdrop", "WaffleBarPopup")

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
