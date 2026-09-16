#!/usr/bin/env python3
"""Regression checks for shell surface, dock, Waffle, and English-only contracts."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
failures = []


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def check(condition: bool, message: str) -> None:
    if not condition:
        failures.append(message)


def main() -> None:
    styled_popup = read("modules/bar/StyledPopup.qml")
    for token in (
        "qs.modules.common.perimeter",
        "ConnectedSurfaceGeometry",
        "ConnectedSurfaceFrame",
        "ConnectedSurfaceMask",
        "EdgeTop",
        "EdgeBottom",
        "EdgeLeft",
        "EdgeRight",
    ):
        check(token in styled_popup, f"StyledPopup must preserve connected-perimeter contract: {token}")

    geometry = read("modules/common/perimeter/ConnectedSurfaceGeometry.qml")
    for token in ("EdgeTop", "EdgeBottom", "EdgeLeft", "EdgeRight", "seamOverlap"):
        check(token in geometry, f"ConnectedSurfaceGeometry missing required edge/seam token: {token}")
    check("1 / root.dpr" in geometry or "1 / dpr" in geometry,
          "ConnectedSurfaceGeometry must retain DPR-aware seam overlap")

    dock_config = read("modules/settings/DockConfig.qml")
    dock_config_lower = dock_config.lower()
    for legacy_style in ('value: "pill"', 'value: "macos"', 'value: "island"', 'value: "m3"'):
        check(legacy_style not in dock_config_lower,
              f"Dock settings must not expose legacy style option {legacy_style}")
    check('panelFamily !== "waffle"' in dock_config,
          "Waffle must remain a separate panel family rather than a Dock style")

    settings_registry = read("modules/settings/SettingsPageRegistry.qml")
    check('Config.setNestedValue("dock.style", "panel")' in settings_registry,
          "Legacy Dock styles must normalize to Panel")
    check('Config.setNestedValue("language.ui", "en_US")' in settings_registry,
          "Legacy UI locales must normalize to canonical en_US")

    settings_sources = "\n".join(
        path.read_text(encoding="utf-8")
        for path in (ROOT / "modules/settings").glob("*.qml")
    )
    check("connectedPerimeter" not in settings_sources,
          "Connected Perimeter must not gain a user-facing settings key")

    translation = read("services/Translation.qml")
    check('availableLanguages: ["en_US"]' in translation,
          "Translation runtime must expose only en_US")
    check('languageCode: "en_US"' in translation,
          "Translation runtime languageCode must stay canonical en_US")
    locale_files = sorted(path.name for path in (ROOT / "translations").glob("*.json"))
    check(locale_files == ["en_US.json"],
          f"Only translations/en_US.json is allowed; found {locale_files}")

    general_config = read("modules/settings/GeneralConfigCore.qml")
    check("Interface Language" not in general_config,
          "English-only settings must not reintroduce an Interface Language selector")
    check("Generate translations" not in general_config,
          "English-only settings must not reintroduce translation generation UI")

    if failures:
        print("Shell surface contract regression(s):")
        for failure in failures:
            print(f"  - {failure}")
        raise SystemExit(1)

    print("Shell surface contracts: OK")


if __name__ == "__main__":
    main()
