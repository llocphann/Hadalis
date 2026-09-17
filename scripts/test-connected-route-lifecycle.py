#!/usr/bin/env python3
"""Regression checks for supported connected-surface presentation lifecycle."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
failures: list[str] = []


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def check(condition: bool, message: str) -> None:
    if not condition:
        failures.append(message)


def main() -> None:
    popup = read("modules/bar/StyledPopup.qml")
    media = read("modules/bar/Media.qml")
    weather_bar = read("modules/bar/weather/WeatherBar.qml")
    weather_popup = read("modules/bar/weather/WeatherPopup.qml")
    sidebar = read("modules/sidebar/SidebarEdgeConnectors.qml")

    for token in (
        "property bool requestedVisible",
        "property bool _lingerVisible",
        "property real revealProgress",
        "readonly property bool visualVisible",
        "retractTimer",
        "progress: root.revealProgress",
        "mask: connectedMask",
    ):
        check(token in popup,
              f"StyledPopup missing supported connected lifecycle contract: {token}")

    check("root.requestedVisible || root._lingerVisible" in popup,
          "StyledPopup must remain resident through its retract tail")
    check("inputEnabled: root.requestedVisible" in popup,
          "StyledPopup must revoke semantic input when a click popup closes")

    check(media.count("StyledPopup {") >= 2,
          "Media wheel HUD and expanded controls must use StyledPopup")
    check("keyboardFocus: true" in media,
          "Expanded Media popup must retain keyboard focus ownership")
    check("SurfaceRouteController" not in media
          and "qs.modules.perimeter" not in media,
          "Normal Media UX must not depend on retired broad perimeter routing")

    check("StyledPopup {" in weather_popup,
          "Weather hover popup must use the supported StyledPopup shell")
    check('GlobalStates.sidebarRightRequestedWidget = "weather"' in weather_bar
          and "GlobalStates.openSidebarRight" in weather_bar,
          "Weather primary activation must route to the right-sidebar Weather tab")
    check("SurfaceRouteController" not in weather_bar
          and "SurfaceRouteController" not in weather_popup,
          "Normal Weather UX must not depend on retired broad perimeter routing")

    for token in (
        "ConnectedSurfaceConnector",
        'BridgeWindow { edge: "left" }',
        'BridgeWindow { edge: "right" }',
    ):
        check(token in sidebar,
              f"Sidebar connected route contract missing: {token}")

    if failures:
        print("Connected presentation lifecycle regression(s):")
        for failure in failures:
            print(f"  - {failure}")
        raise SystemExit(1)

    print("Connected presentation lifecycle: OK")


if __name__ == "__main__":
    main()
