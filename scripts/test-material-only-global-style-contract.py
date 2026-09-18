#!/usr/bin/env python3
"""Regression contract for the v1.0 Material-only global style boundary."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APPEARANCE = ROOT / "modules" / "common" / "Appearance.qml"
THEME_SERVICE = ROOT / "services" / "ThemeService.qml"
STYLED_POPUP = ROOT / "modules" / "bar" / "StyledPopup.qml"
SETTINGS_OVERLAY = ROOT / "modules" / "settings" / "SettingsOverlay.qml"
SETTINGS_WINDOW = ROOT / "settings.qml"


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
    settings_window = SETTINGS_WINDOW.read_text(encoding="utf-8")

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

    blur_start = appearance.index("function blurBackendFor(")
    blur_end = appearance.index("function useCompositorBlur(", blur_start)
    blur_contract = appearance[blur_start:blur_end]
    for token in (
        "auroraEverywhere",
        "angelEverywhere",
        "zzzEverywhere",
    ):
        forbid(blur_contract, token, "Appearance.qml blur backend")
    require(
        blur_contract,
        'if (area === "islands" || area === "waffle")',
        "Appearance.qml blur backend",
    )

    hover_start = appearance.index("// Stable aliases for the canonical Material interaction fills")
    hover_end = appearance.index("onEffectsEnabledChanged", hover_start)
    hover_contract = appearance[hover_start:hover_end]
    for token in (
        "regaliaEverywhere",
        "cookieEverywhere",
        "zzzEverywhere",
        "angelEverywhere",
        "inirEverywhere",
        "auroraEverywhere",
    ):
        forbid(hover_contract, token, "Appearance.qml interaction aliases")
    for token in (
        "readonly property color colLayer1Hover: colors.colLayer1Hover",
        "readonly property color colLayer2Hover: colors.colLayer2Hover",
        "readonly property color colLayer1Active: colors.colLayer1Active",
    ):
        require(hover_contract, token, "Appearance.qml interaction aliases")

    warning_start = appearance.index("readonly property color colWarning:")
    warning_end = appearance.index("readonly property color colInfo:", warning_start)
    warning_contract = appearance[warning_start:warning_end]
    forbid(warning_contract, "zzzEverywhere", "Appearance.qml warning tokens")
    for token in (
        "root.m3colors.m3tertiary, 0.42",
        "readonly property color colOnWarningContainer: root.m3colors.m3onTertiaryContainer",
    ):
        require(warning_contract, token, "Appearance.qml warning tokens")

    colors_success_start = appearance.index("property color colSuccess:")
    rounding_start = appearance.index("rounding: QtObject {", colors_success_start)
    colors_success = appearance[colors_success_start:rounding_start]
    for token in ("regaliaEverywhere", "zzzEverywhere"):
        forbid(colors_success, token, "Appearance.qml success/warning colors")
    for token in (
        "property color colSuccess: m3colors.m3success",
        "property color colWarningContainer: m3colors.m3tertiaryContainer",
        "property color colOnWarningContainer: m3colors.m3onTertiaryContainer",
    ):
        require(colors_success, token, "Appearance.qml success/warning colors")

    typography_start = appearance.index("// Typography scale factor from config", rounding_start)
    rounding_contract = appearance[rounding_start:typography_start]
    for token in ("regaliaEverywhere", "cookieEverywhere", "zzzEverywhere"):
        forbid(rounding_contract, token, "Appearance.qml rounding")
    for token in (
        "property real scale: root._themeMeta.roundingScale ?? 1.0",
        "property int full: 9999",
        "property int windowRounding: Math.max(0, Math.round(18 * scale))",
    ):
        require(rounding_contract, token, "Appearance.qml rounding")

    font_strategy_start = appearance.index("// Material typography may still request", typography_start)
    animation_curves_start = appearance.index("animationCurves: QtObject {", font_strategy_start)
    font_contract = appearance[font_strategy_start:animation_curves_start]
    for token in (
        'globalStyle === "inir"',
        'globalStyle === "angel"',
        'globalStyle === "regalia"',
        'globalStyle === "zzz"',
        "regaliaEverywhere",
    ):
        forbid(font_contract, token, "Appearance.qml font dispatch")
    for token in (
        'readonly property bool _forceMono: _themeMeta.fontStyle === "mono"',
        "readonly property bool _useAngelFont: false",
        "readonly property bool _useRegaliaFont: false",
        "readonly property bool _useZzzFont: false",
        'property string numbers: "Rubik"',
        '"wght": 900',
    ):
        require(font_contract, token, "Appearance.qml font dispatch")

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

    # Window-mode Settings uses the same Material-only public contract.
    for token in ("ZzzDiagonalPattern {", "ZzzSurfaceAccent {"):
        forbid(settings_window, token, "settings.qml root chrome")
    require(
        settings_window,
        "? Appearance.m3colors.m3background",
        "settings.qml root chrome",
    )
    window_search_start = settings_window.index("id: searchContainer")
    window_nav_start = settings_window.index("id: navRail", window_search_start)
    window_search = settings_window[window_search_start:window_nav_start]
    for token in (
        "Appearance.zzzEverywhere",
        "Appearance.regaliaEverywhere",
        "Appearance.angelEverywhere",
        "Appearance.inirEverywhere",
        "Appearance.auroraEverywhere",
    ):
        forbid(window_search, token, "settings.qml search chrome")
    for token in (
        "? Appearance.colors.colLayer1",
        ": Appearance.colors.colLayer0",
        "border.width: settingsSearchField.activeFocus ? 2 : 1",
        ": Appearance.m3colors.m3outlineVariant",
    ):
        require(window_search, token, "settings.qml search chrome")

    window_nav_start = settings_window.index("id: navCol")
    window_nav_end = settings_window.index("id: navBottomActions", window_nav_start)
    window_nav = settings_window[window_nav_start:window_nav_end]
    for token in (
        "Appearance.zzzEverywhere",
        "Appearance.regaliaEverywhere",
        "Appearance.angelEverywhere",
        "Appearance.inirEverywhere",
        "Appearance.auroraEverywhere",
        "ZzzPlate {",
    ):
        forbid(window_nav, token, "settings.qml navigation rail")
    for token in (
        "rippleEnabled: true",
        "buttonRadius: Math.min(width, height) / 2",
        "colBackgroundHover: Appearance.colors.colLayer1Hover",
        "id: sharedNavIndicator",
        "color: Appearance.colors.colPrimaryContainer",
    ):
        require(window_nav, token, "settings.qml navigation rail")

    # The standalone Settings window is now collapsed entirely to its Material
    # fallbacks, not just root/search/navigation chrome.
    for token in (
        "Appearance.zzzEverywhere",
        "Appearance.regaliaEverywhere",
        "Appearance.angelEverywhere",
        "Appearance.inirEverywhere",
        "Appearance.auroraEverywhere",
        "Appearance.cookieEverywhere",
    ):
        forbid(settings_window, token, "settings.qml")

    window_content_start = settings_window.index("id: contentContainer")
    window_results_start = settings_window.index("id: searchResultsCard", window_content_start)
    window_content = settings_window[window_content_start:window_results_start]
    for token in (
        "color: Appearance.colors.colSurfaceContainerLow",
        "radius: Appearance.rounding.windowRounding - root.contentPadding",
        "border.width: 0",
        'border.color: "transparent"',
        "color: Appearance.m3colors.m3outlineVariant",
    ):
        require(window_content, token, "settings.qml content container")

    window_results_end = settings_window.index("id: resultsListView", window_results_start)
    window_results = settings_window[window_results_start:window_results_end]
    for token in (
        "radius: Appearance.rounding.normal",
        "border.width: 1",
        "border.color: Appearance.m3colors.m3outlineVariant",
        "layer.enabled: Appearance.effectsEnabled",
    ):
        require(window_results, token, "settings.qml search results card")

    results_delegate_start = settings_window.index("id: resultItem", window_results_end)
    results_delegate_end = settings_window.index("contentItem: RowLayout", results_delegate_start)
    results_delegate = settings_window[results_delegate_start:results_delegate_end]
    for token in (
        "buttonRadius: Appearance.rounding.small",
        "? Appearance.colors.colPrimaryContainer",
        "colBackgroundHover: Appearance.colors.colLayer2",
    ):
        require(results_delegate, token, "settings.qml search result delegate")

    print("Material-only global style contract: PASS")


if __name__ == "__main__":
    main()
