#!/usr/bin/env python3
"""Regression contract for public Material-only Themes settings."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REGISTRY = ROOT / "modules" / "settings" / "SettingsPageRegistry.qml"
REGISTRY_DATA = ROOT / "modules" / "settings" / "SettingsPageRegistryData.qml"
THEMES = ROOT / "modules" / "settings" / "ThemesConfig.qml"
FACADE = ROOT / "modules" / "settings" / "ThemesConfigMaterial.qml"
QMLDIR = ROOT / "modules" / "settings" / "qmldir"


def require(text: str, token: str, source: str) -> None:
    if token not in text:
        raise AssertionError(
            f"{source} is missing required Material-only settings token: {token!r}"
        )


def forbid(text: str, token: str, source: str) -> None:
    if token in text:
        raise AssertionError(
            f"{source} still contains retired Global Style UI/routing: {token!r}"
        )


def main() -> None:
    registry = REGISTRY.read_text(encoding="utf-8")
    registry_data = REGISTRY_DATA.read_text(encoding="utf-8")
    themes = THEMES.read_text(encoding="utf-8")
    facade = FACADE.read_text(encoding="utf-8")
    qmldir = QMLDIR.read_text(encoding="utf-8")

    for token in (
        "readonly property int themesPageIndex: 4",
        'component: "modules/settings/ThemesConfigMaterial.qml"',
        'desc: Translation.tr("Material colors, typography and motion")',
    ):
        require(registry, token, "SettingsPageRegistry.qml")

    for token in (
        "retiredGlobalStyleKeywords",
        "isRetiredGlobalStyleEntry",
        ".filter(entry => !root.isRetiredGlobalStyleEntry(entry))",
    ):
        forbid(registry, token, "SettingsPageRegistry.qml")

    for token in (
        'summary: Translation.tr("Colors · typography · motion · advanced")',
        '{ displayName: Translation.tr("Colors"), icon: "palette", value: "colors" }',
        '{ displayName: Translation.tr("Type"), icon: "text_format", value: "type" }',
        '{ displayName: Translation.tr("Motion"), icon: "animation", value: "motion" }',
        '{ displayName: Translation.tr("Advanced"), icon: "construction", value: "advanced" }',
    ):
        require(themes, token, "ThemesConfig.qml")

    for token in (
        'value: "style"',
        'settingsTaskSection: "style"',
        'Translation.tr("Global Style")',
        "ThemeService.setGlobalStyle(",
        "AuroraStyleEditor.qml",
        "AngelStyleEditor.qml",
        "RegaliaStyleEditor.qml",
        "ZzzStyleEditor.qml",
        "Appearance.zzzEverywhere",
        "Appearance.regaliaEverywhere",
        "Appearance.angelEverywhere",
        "Appearance.inirEverywhere",
        "Appearance.auroraEverywhere",
        "Appearance.cookieEverywhere",
    ):
        forbid(themes, token, "ThemesConfig.qml")

    forbid(
        registry_data,
        'section: Translation.tr("Global Style")',
        "SettingsPageRegistryData.qml",
    )

    for token in (
        "ThemesConfig {",
        "ThemeService.normalizeGlobalStyle()",
        'if (activeSection === "style")',
        'activeSection = "colors"',
    ):
        require(facade, token, "ThemesConfigMaterial.qml")

    for token in (
        "_stripRetiredGlobalStyleUi",
        'item.settingsTaskSection === "style"',
        'option?.value !== "style"',
    ):
        forbid(facade, token, "ThemesConfigMaterial.qml")

    require(qmldir, "ThemesConfig 1.0 ThemesConfig.qml", "qmldir")
    require(qmldir, "ThemesConfigMaterial 1.0 ThemesConfigMaterial.qml", "qmldir")

    print("Material-only public Themes settings contract: PASS")


if __name__ == "__main__":
    main()
