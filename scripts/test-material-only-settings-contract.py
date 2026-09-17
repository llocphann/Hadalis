#!/usr/bin/env python3
"""Regression contract for the public Material-only Themes settings facade."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REGISTRY = ROOT / "modules" / "settings" / "SettingsPageRegistry.qml"
FACADE = ROOT / "modules" / "settings" / "ThemesConfigMaterial.qml"
QMLDIR = ROOT / "modules" / "settings" / "qmldir"


def require(text: str, token: str, source: str) -> None:
    if token not in text:
        raise AssertionError(f"{source} is missing required Material-only settings token: {token!r}")


def main() -> None:
    registry = REGISTRY.read_text(encoding="utf-8")
    facade = FACADE.read_text(encoding="utf-8")
    qmldir = QMLDIR.read_text(encoding="utf-8")

    for token in (
        "readonly property int themesPageIndex: 4",
        'component: "modules/settings/ThemesConfigMaterial.qml"',
        'entry.section === Translation.tr("Global Style")',
        'entry.label === Translation.tr("Global Style")',
        ".filter(entry => !root.isRetiredGlobalStyleEntry(entry))",
    ):
        require(registry, token, "SettingsPageRegistry.qml")

    for token in (
        "ThemesConfig {",
        "ThemeService.normalizeGlobalStyle()",
        'option?.value !== "style"',
        'item.settingsTaskSection === "style"',
        'if (activeSection === "style")',
        'activeSection = "colors"',
    ):
        require(facade, token, "ThemesConfigMaterial.qml")

    require(qmldir, "ThemesConfig 1.0 ThemesConfig.qml", "qmldir")
    require(qmldir, "ThemesConfigMaterial 1.0 ThemesConfigMaterial.qml", "qmldir")

    print("Material-only public Themes settings contract: PASS")


if __name__ == "__main__":
    main()
