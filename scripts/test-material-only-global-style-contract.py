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

    identity_start = settings_overlay.index("id: overlayHeaderIdentity")
    search_start = settings_overlay.index("id: overlaySearchContainer", identity_start)
    actions_start = settings_overlay.index("id: overlayHeaderActions", search_start)
    identity_chrome = settings_overlay[identity_start:search_start]
    search_chrome = settings_overlay[search_start:actions_start]
    for source, chrome in (
        ("SettingsOverlay.qml identity chrome", identity_chrome),
        ("SettingsOverlay.qml search chrome", search_chrome),
    ):
        for token in (
            "Appearance.zzzEverywhere",
            "Appearance.regaliaEverywhere",
            "Appearance.angelEverywhere",
            "Appearance.inirEverywhere",
            "Appearance.auroraEverywhere",
        ):
            forbid(chrome, token, source)
    forbid(identity_chrome, "RegaliaControlFace {", "SettingsOverlay.qml identity chrome")
    for token in (
        "radius: width / 2",
        "color: Appearance.colors.colLayer1",
        "border.width: 1",
    ):
        require(identity_chrome, token, "SettingsOverlay.qml identity chrome")
    for token in (
        "? Appearance.colors.colLayer1",
        ": Appearance.colors.colSurfaceContainerLow",
        "border.width: overlaySearchField.activeFocus ? 2 : 1",
        ": Appearance.colors.colOutlineVariant",
    ):
        require(search_chrome, token, "SettingsOverlay.qml search chrome")

    nav_start = settings_overlay.index("id: navColumn")
    nav_end = settings_overlay.index("id: overlayNavActions", nav_start)
    nav_chrome = settings_overlay[nav_start:nav_end]
    for token in (
        "Appearance.zzzEverywhere",
        "Appearance.regaliaEverywhere",
        "Appearance.angelEverywhere",
        "Appearance.inirEverywhere",
        "Appearance.auroraEverywhere",
        "ZzzPlate {",
    ):
        forbid(nav_chrome, token, "SettingsOverlay.qml navigation rail")
    for token in (
        "rippleEnabled: true",
        "buttonRadius: Math.min(width, height) / 2",
        "colBackgroundHover: Appearance.colors.colLayer1Hover",
        "id: sharedNavIndicator",
        "color: Appearance.colors.colPrimaryContainer",
    ):
        require(nav_chrome, token, "SettingsOverlay.qml navigation rail")

    actions_start = settings_overlay.index("id: overlayNavActions")
    content_start = settings_overlay.index("id: overlayContentContainer", actions_start)
    search_results_start = settings_overlay.index(
        "id: overlaySearchResultsOverlay", content_start
    )
    nav_actions = settings_overlay[actions_start:content_start]
    content_chrome = settings_overlay[content_start:search_results_start]
    for source, chrome in (
        ("SettingsOverlay.qml navigation actions", nav_actions),
        ("SettingsOverlay.qml content container", content_chrome),
    ):
        for token in (
            "Appearance.zzzEverywhere",
            "Appearance.regaliaEverywhere",
            "Appearance.angelEverywhere",
            "Appearance.inirEverywhere",
            "Appearance.auroraEverywhere",
        ):
            forbid(chrome, token, source)
    forbid(content_chrome, "GlassBackground {", "SettingsOverlay.qml content container")
    for token in (
        "radius: Appearance.rounding.normal",
        "color: Appearance.colors.colSurfaceContainerLow",
        "border.width: 0",
        'border.color: "transparent"',
    ):
        require(content_chrome, token, "SettingsOverlay.qml content container")

    # SettingsOverlay is active v1.0 runtime. Once each scoped chrome
    # block has been collapsed to its Material fallback, no shell-wide legacy
    # style predicate may remain anywhere in the file.
    for token in (
        "Appearance.zzzEverywhere",
        "Appearance.regaliaEverywhere",
        "Appearance.angelEverywhere",
        "Appearance.inirEverywhere",
        "Appearance.auroraEverywhere",
        "Appearance.cookieEverywhere",
    ):
        forbid(settings_overlay, token, "SettingsOverlay.qml")

    print("Material-only global style contract: PASS")


if __name__ == "__main__":
    main()
