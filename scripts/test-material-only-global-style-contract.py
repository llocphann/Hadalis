#!/usr/bin/env python3
"""Regression contract for the v1.0 Material-only global style boundary."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APPEARANCE = ROOT / "modules" / "common" / "Appearance.qml"
THEME_SERVICE = ROOT / "services" / "ThemeService.qml"
STYLED_POPUP = ROOT / "modules" / "bar" / "StyledPopup.qml"
SETTINGS_OVERLAY = ROOT / "modules" / "settings" / "SettingsOverlay.qml"


def require(text: str, token: str, source: str) -> None:
    if token not in text:
        raise AssertionError(
            f"{source} is missing required Material-only contract token: {token!r}"
        )


def forbid(text: str, token: str, source: str) -> None:
    if token in text:
        raise AssertionError(
            f"{source} still contains retired global-style routing: {token!r}"
        )


def main() -> None:
    appearance = APPEARANCE.read_text(encoding="utf-8")
    theme_service = THEME_SERVICE.read_text(encoding="utf-8")
    styled_popup = STYLED_POPUP.read_text(encoding="utf-8")
    settings_overlay = SETTINGS_OVERLAY.read_text(encoding="utf-8")

    # Runtime must never expose a persisted legacy shell-wide style, even during
    # singleton initialization before ThemeService has normalized config on disk.
    require(
        appearance,
        'readonly property string globalStyle: "material"',
        "Appearance.qml",
    )
    forbid(
        appearance,
        'readonly property string globalStyle: Config?.options?.appearance?.globalStyle ?? "material"',
        "Appearance.qml",
    )

    # Persistence migration remains owned by ThemeService: old callers/config may
    # still reach this compatibility boundary, but every value is clamped to Material.
    for token in (
        'readonly property string supportedGlobalStyle: "material"',
        'function normalizeGlobalStyle(): void',
        'Config.setNestedValue("appearance.globalStyle", root.supportedGlobalStyle)',
        'function setGlobalStyle(styleId: string): void',
        'if (styleId !== root.supportedGlobalStyle)',
        'root.normalizeGlobalStyle()',
    ):
        require(theme_service, token, "ThemeService.qml")

    # The compatibility setter may remain for old callers, but it must never
    # persist the requested legacy style or resurrect per-style shell geometry.
    for token in (
        '"appearance.globalStyle": styleId',
        'const cards = styleId === "cards"',
        'case "cards":',
        'case "aurora":',
        'case "inir":',
        'case "angel":',
        'case "regalia":',
        'case "zzz":',
        'case "cookie":',
    ):
        forbid(theme_service, token, "ThemeService.qml")

    # The shared connected-popup path is user-facing runtime, not migration
    # compatibility. It must consume the canonical Material tokens directly.
    for token in (
        'readonly property color _surfaceColor: Appearance.colors.colLayer0',
        'readonly property color _borderColor: Appearance.colors.colLayer0Border',
        'readonly property real _borderWidth: 0',
        'readonly property real _surfaceRadius: Appearance.rounding.large',
    ):
        require(styled_popup, token, "StyledPopup.qml")

    for token in (
        "Appearance.zzzEverywhere",
        "Appearance.regaliaEverywhere",
        "Appearance.angelEverywhere",
        "Appearance.inirEverywhere",
        "Appearance.auroraEverywhere",
    ):
        forbid(styled_popup, token, "StyledPopup.qml")

    # The outer Settings panel is active Material runtime, not migration
    # compatibility. Keep legacy style renderers out of this container.
    card_start = settings_overlay.index("id: settingsCard")
    card_end = settings_overlay.index("// Prevent clicks from closing", card_start)
    settings_card = settings_overlay[card_start:card_end]
    for token in (
        "Appearance.zzzEverywhere",
        "Appearance.regaliaEverywhere",
        "Appearance.angelEverywhere",
        "Appearance.inirEverywhere",
        "Appearance.auroraEverywhere",
        "RegaliaPlate {",
        "GlassBackground {",
        "ZzzPanelBackdrop {",
    ):
        forbid(settings_card, token, "SettingsOverlay.qml outer Settings card")
    for token in (
        "radius: Appearance.rounding.windowRounding",
        "Appearance.colors.colLayer0Base",
        "border.width: 0",
        'border.color: "transparent"',
    ):
        require(settings_card, token, "SettingsOverlay.qml outer Settings card")
    forbid(settings_overlay, "Themes · Global Style", "SettingsOverlay.qml")

    print("Material-only global style contract: PASS")


if __name__ == "__main__":
    main()
