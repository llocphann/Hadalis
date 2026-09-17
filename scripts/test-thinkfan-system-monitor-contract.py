#!/usr/bin/env python3
"""Regression contract for the v1.0 ThinkFan/System Monitor integration."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
failures: list[str] = []


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def check(condition: bool, message: str) -> None:
    if not condition:
        failures.append(message)


def main() -> None:
    resources_popup = read("modules/bar/ResourcesPopup.qml")
    thinkfan_module = read("modules/perimeter/ThinkFanModule.qml")
    bar_settings = read("modules/settings/BarConfigHugOnly.qml")
    perimeter_qmldir = read("modules/perimeter/qmldir")

    for token in (
        "ThinkFanService.refresh()",
        "ThinkFanService.applyProfile(",
        'Translation.tr("ThinkFan")',
        'Translation.tr("Fan speed")',
        'Translation.tr("Fan level")',
        'Translation.tr("Service")',
        "thinkFanCanApply",
        "thinkFanApplyErrorMessage",
    ):
        check(token in resources_popup,
              f"System Monitor popup must own ThinkFan runtime UI: {token}")

    for forbidden in (
        "ThinkFanConnectedSurface",
        "SurfaceRouteController",
        "AnchorPublisher",
        'surface: "thinkfan"',
    ):
        check(forbidden not in thinkfan_module,
              f"ThinkFan perimeter indicator must not own a standalone popup route: {forbidden}")

    check("Accessible.role: Accessible.StaticText" in thinkfan_module,
          "Non-interactive ThinkFan perimeter telemetry must expose static-text accessibility semantics")

    for token in (
        'title: Translation.tr("System Monitor & Thermals")',
        'text: Translation.tr("ThinkFan managed control")',
        "ThinkFanService.applyProfile(",
        "checked: root.thinkFanManaged",
    ):
        check(token in bar_settings,
              f"Bar Settings must expose the shared ThinkFan profile control: {token}")

    check("ThinkFanConnectedSurface" not in perimeter_qmldir,
          "Retired standalone ThinkFan connected surface must not remain exported")
    check("ThinkFanPopupContent" not in perimeter_qmldir,
          "Retired standalone ThinkFan popup content must not remain exported")
    check(not (ROOT / "modules/perimeter/ThinkFanConnectedSurface.qml").exists(),
          "Retired standalone ThinkFan connected surface file must be removed")
    check(not (ROOT / "modules/perimeter/ThinkFanPopupContent.qml").exists(),
          "Retired standalone ThinkFan popup content file must be removed")

    if failures:
        print("ThinkFan/System Monitor contract regression(s):")
        for failure in failures:
            print(f"  - {failure}")
        raise SystemExit(1)

    print("ThinkFan/System Monitor contract: OK")


if __name__ == "__main__":
    main()
