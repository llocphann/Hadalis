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
        "mask: connectedMask",
        "ExclusionMode.Ignore",
    ):
        check(token in styled_popup, f"StyledPopup must preserve connected-perimeter contract: {token}")
    for edge in ("top", "bottom", "left", "right"):
        check(f'"{edge}"' in styled_popup,
              f"StyledPopup must preserve {edge} attachment handling")

    geometry = read("modules/common/perimeter/ConnectedSurfaceGeometry.qml")
    for edge in ("top", "bottom", "left", "right"):
        check(f'edge === "{edge}"' in geometry,
              f"ConnectedSurfaceGeometry missing {edge} edge handling")
    for token in (
        "seamOverlap",
        "effectiveSeamOverlap",
        "devicePixelRatio",
        "function pixelScale()",
        "function snap(",
        "connectorRectForBody",
        "animatedBodyRect",
    ):
        check(token in geometry,
              f"ConnectedSurfaceGeometry missing seam/reveal geometry contract: {token}")

    frame = read("modules/common/perimeter/ConnectedSurfaceFrame.qml")
    check("connectorBorderWidth: 0" not in frame,
          "ConnectedSurfaceFrame should expose connectorBorderWidth as a configurable property, not hard-code it internally")
    check("Render after the body so seamOverlap covers the body's border" in frame,
          "ConnectedSurfaceFrame must preserve the body/connector seam-overlap rendering contract")

    dock_config = read("modules/settings/DockConfig.qml")
    dock_config_lower = dock_config.lower()
    for legacy_style in ('value: "pill"', 'value: "macos"', 'value: "island"', 'value: "m3"'):
        check(legacy_style not in dock_config_lower,
              f"Dock settings must not expose legacy style option {legacy_style}")
    check('panelFamily !== "waffle"' in dock_config,
          "Waffle must remain a separate panel family rather than a Dock style")
    check("Dock uses the Panel surface style." in dock_config,
          "Dock settings must describe Panel as the canonical surface style")

    settings_registry = read("modules/settings/SettingsPageRegistry.qml")
    check('Config.setNestedValue("dock.style", "panel")' in settings_registry,
          "Legacy Dock styles must normalize to Panel")
    check('Config.setNestedValue("language.ui", "en_US")' in settings_registry,
          "Legacy UI locales must normalize to canonical en_US")

    shell = read("shell.qml")
    check("DevNavigation.registerSettingsPages(SettingsPageRegistry.pages)" in shell,
          "Shell startup must materialize SettingsPageRegistry so legacy config normalization runs without opening Settings")

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
    check('translations/en_US.json' in translation,
          "Translation runtime must load the canonical en_US catalog")
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
