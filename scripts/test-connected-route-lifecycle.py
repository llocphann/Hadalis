#!/usr/bin/env python3
"""Regression checks for route-owned connected-surface enter/retract lifecycle."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
failures = []


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def check(condition: bool, message: str) -> None:
    if not condition:
        failures.append(message)


def main() -> None:
    helper = read("modules/common/perimeter/ConnectedSurfaceRouteState.qml")
    qmldir = read("modules/common/perimeter/qmldir")

    check("ConnectedSurfaceRouteState 1.0 ConnectedSurfaceRouteState.qml" in qmldir,
          "ConnectedSurfaceRouteState must be exported by the perimeter module")
    for token in (
        "property var _routeSnapshot",
        "property bool _routeOwned",
        "property bool _lingerVisible",
        "property real revealProgress",
        "readonly property bool visualVisible",
        "Behavior on revealProgress",
        "retractTimer",
        "function onOpened",
        "function onUpdated",
        "function onClosed",
    ):
        check(token in helper,
              f"ConnectedSurfaceRouteState missing lifecycle contract: {token}")
    check("root._routeOwned = false" in helper
          and "root.revealProgress = 0" in helper,
          "Route close must revoke semantic ownership before retracting visual geometry")
    check("root._routeSnapshot = null" in helper,
          "Route snapshot must be released after the retract tail")

    for path, surface_name in (
        ("modules/perimeter/MediaConnectedSurface.qml", "media"),
        ("modules/perimeter/WeatherConnectedSurface.qml", "weather"),
    ):
        source = read(path)
        check("ConnectedSurfaceRouteState {" in source,
              f"{path} must use shared route lifecycle state")
        check(f'surfaceName: "{surface_name}"' in source,
              f"{path} must bind lifecycle state to its own route surface")
        check("visible: routeState.visualVisible && root.sourceScreen !== null" in source,
              f"{path} must stay visually resident during retract")
        check("progress: routeState.revealProgress" in source,
              f"{path} must drive shared connected geometry from route reveal progress")
        check("mask: root.routeOwned ? connectedMask : emptyInputRegion" in source,
              f"{path} must revoke pointer input as soon as semantic ownership closes")
        check("WlrLayershell.keyboardFocus: root.routeOwned" in source,
              f"{path} must revoke layer-shell keyboard focus while retracting")
        check("SurfaceRouteController.current" not in source,
              f"{path} must not bypass the shared route lifecycle state")
        check("(routeState.revealProgress - 0.18) / 0.82" in source,
              f"{path} content must follow the connected-surface reveal threshold")
        check("CompositorService.isNiri" in source
              and 'SurfaceRouteController.dismiss(root.outputName, "focus-loss")' in source,
              f"{path} must dismiss its semantic route after Niri focus loss")

    weather = read("modules/perimeter/WeatherConnectedSurface.qml")
    check("devicePixelRatio: root.sourceScreen?.devicePixelRatio ?? 1" in weather,
          "Weather connected geometry must snap against the owning output scale")
    check("weatherViewport.forceActiveFocus()" in weather,
          "Weather connected surface must request focus so Niri can observe focus loss")

    if failures:
        print("Connected route lifecycle regression(s):")
        for failure in failures:
            print(f"  - {failure}")
        raise SystemExit(1)

    print("Connected route lifecycle: OK")


if __name__ == "__main__":
    main()
