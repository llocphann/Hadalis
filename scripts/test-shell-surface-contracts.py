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
        "ConnectedSurfaceRevealClip",
        "ConnectedSurfaceContentHost",
        "ConnectedSurfaceMask",
        "mask: connectedMask",
        "ExclusionMode.Ignore",
        "Appearance.colors.colLayer0",
        "Appearance.rounding.large",
        "geometry.revealProgress",
        "CompositorFocusGrab",
        "WlrKeyboardFocus.OnDemand",
        "requestedVisible",
        "_lingerVisible",
        "retractTimer",
        "progress: root.revealProgress",
        "property real offsetScale: 1",
        "readonly property real revealProgress: 1 - root.offsetScale",
        "Behavior on offsetScale",
        "|| root.popupHovered",
        "enabled: root.active",
    ):
        check(token in styled_popup, f"StyledPopup must preserve connected-perimeter contract: {token}")
    for edge in ("top", "bottom", "left", "right"):
        check(f'"{edge}"' in styled_popup,
              f"StyledPopup must preserve {edge} attachment handling")
    check("Appearance.colors.colSurfaceContainer" not in styled_popup,
          "Connected bar popups must use the owning bar surface family, not the detached popup-card material")
    check("root._anchorReady" in styled_popup
          and "root.requestedVisible || root._lingerVisible" in styled_popup,
          "Connected popout loader must require a real anchor and stay resident long enough to retract into it")
    check("cornerStyle" not in styled_popup,
          "Connected bar popouts must not branch on retired Classic Bar corner styles")
    check("Appearance.zzz.chromeAlt" not in styled_popup
          and "Appearance.regalia.barSurfaceFloating" not in styled_popup,
          "Connected bar popouts must use the Hug surface family only")

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
        "connectorSourceExtent",
        "connectorBodyExtent",
        "animatedTangentExtent",
        "animatedCrossExtent",
        "revealProgress",
        "motionProgress",
        "connectorRectForBody",
        "animatedBodyRect",
    ):
        check(token in geometry,
              f"ConnectedSurfaceGeometry missing seam/morph geometry contract: {token}")
    check("property real connectorWidth: PerimeterTokens.connectorWidth" in geometry,
          "ConnectedSurfaceGeometry must source popup connector width from the shared perimeter token")
    check("Math.max(Math.max(0, connectorWidth), anchorTangentExtent)" not in geometry,
          "Connected popup neck width must not expand or shrink with the source control width")
    check("(1 - motionProgress) * crossBodyExtent" in geometry,
          "Connected popup motion must translate the complete body with the expressive spatial scalar")
    check("readonly property real revealProgress: clamp(progress, 0, 1)" in geometry
          and "readonly property real motionProgress:" in geometry,
          "Connected popup must clamp semantic reveal while preserving spatial overshoot for translation")
    check("readonly property rect revealClipRect:" in geometry,
          "Connected popup reveal must expose a fixed resting-edge clip")
    check("readonly property rect visibleBodyRect:" in geometry,
          "Connected popup input must follow only the revealed body segment")
    check("crossBodyExtent * revealProgress" not in geometry,
          "Connected popup reveal must not shrink the body cross-axis")
    check("(bodyTangentExtent - connectorSourceExtent) * revealProgress" not in geometry,
          "Connected popup reveal must not expand from a narrow neck")
    check("bodyRect.width, bodyRect.height" in geometry,
          "Connected popup slide must preserve the full body size")
    check("tangentAnimationOffset" not in geometry
          and "tangentRevealDirection" not in geometry,
          "Connected popup slide must remain on the attachment axis like Caelestia wrappers")
    check("ConnectedSurfaceRevealClip {" in styled_popup
          and "opacity: 1" in styled_popup,
          "Connected popup must use pure slide-under clipping instead of staged fade/scale")

    content_host = read("modules/common/perimeter/ConnectedSurfaceContentHost.qml")
    for token in ("geometry.animatedBodyRect", "effectivePadding", "clip: true"):
        check(token in content_host,
              f"ConnectedSurfaceContentHost must centralize live padded body placement: {token}")

    connector = read("modules/common/perimeter/ConnectedSurfaceConnector.qml")
    check("Canvas {" in connector,
          "ConnectedSurfaceConnector must render a shaped shoulder rather than a rectangular stem")
    check("bezierCurveTo" in connector,
          "ConnectedSurfaceConnector must retain curved shoulder transitions")
    check("connectorSourceExtent" in connector,
          "ConnectedSurfaceConnector must narrow toward the real bar anchor")

    join_flares = read("modules/common/perimeter/ConnectedSurfaceJoinFlares.qml")
    for token in (
        "readonly property point bodyOrigin:",
        "root.bodyItem.mapToItem(root, 0, 0)",
        "root.bodyOrigin.x",
        "root.bodyOrigin.y",
    ):
        check(token in join_flares,
              f"Join flares must map nested body coordinates into their host: {token}")

    check("hoverEnabled: root.active" in styled_popup
          and "onBodyHoveredChanged: root.popupHovered = bodyHovered" in styled_popup,
          "StyledPopup hover bridge must track the complete popup body instead of padded content")
    check("property QtObject _hoverTransferTimerObject: Timer {" in styled_popup
          and "interval: 90" in styled_popup
          and "hoverTransferTimer.restart()" in styled_popup,
          "StyledPopup must debounce the compositor leave/enter hand-off across Bar and popup windows")

    screen_edge = read("modules/screenCorners/ScreenEdges.qml")
    check("Config.options?.appearance?.screenEdge?.width ?? 10" in screen_edge,
          "Screen Edge must default to 10px while remaining user-adjustable")
    check("screenEdge?.enable" not in screen_edge,
          "Screen Edge must not be disabled by stale persisted enable flags")
    check("!GlobalStates.screenLocked" in screen_edge and "!fullscreenCovered" in screen_edge,
          "Screen Edge must stay mapped normally and hide only for lock/fullscreen coverage")
    check("mask: Region { item: emptyInput }" in screen_edge,
          "Screen Edge must remain completely click-through")
    for edge in ("top", "bottom", "left", "right"):
        check(f'EdgeWindow {{ edge: "{edge}" }}' in screen_edge,
              f"Screen Edge must render the persistent {edge} output edge")

    sidebar_host = read("modules/sidebar/SidebarHost.qml")
    for token in (
        "GlobalStates.sidebarLeftPresentationOutput",
        "GlobalStates.sidebarRightPresentationOutput",
        "PanelWindow {",
        "width: Math.max(0, root.effectiveSidebarWidth",
        "- Appearance.sizes.elevationMargin)",
        "rightMargin: root.isLeftEdge",
        "? Appearance.sizes.elevationMargin",
        ": 0",
        "leftMargin: root.isLeftEdge",
        "? 0",
        ": Appearance.sizes.elevationMargin",
    ):
        check(token in sidebar_host,
              f"Sidebar physical-edge underlap contract missing: {token}")
    for retired in (
        "ConnectedSurfaceConnector",
        "sidebarBridgeGeometry",
        "directEdgeInset",
        "screenEdgeThickness",
    ):
        check(retired not in sidebar_host,
              f"Sidebar must not stop at an inner-edge inset or restore a connector: {retired}")
    check('property: "animTranslateX"' in sidebar_host
          and 'property: "animTranslateY"' in sidebar_host
          and "Appearance.animation?.elementMove?.duration ?? 500" in sidebar_host
          and "Appearance.animation?.elementMove?.bezierCurve" in sidebar_host,
          "Sidebar slide translation must use the default-spatial motion token")

    osk = read("modules/onScreenKeyboard/OnScreenKeyboard.qml")
    for token in (
        "targetY = 0",
        "targetY = ph - kh",
        "y: parent ? parent.height - height : 0",
        "ConnectedSurfaceJoinFlares {",
        "flareRadius: PerimeterTokens.joinFlareRadius",
        'joinTop: oskRoot.snappedEdge === "top"',
        'joinBottom: oskRoot.snappedEdge === "bottom"',
    ):
        check(token in osk,
              f"OSK physical Screen Edge attachment contract missing: {token}")
    check("screenAttachInset" not in osk,
          "OSK must not stop at the inner Screen Edge boundary")
    check("Appearance.animation.elementMove.duration" in osk
          and "Appearance.animation.elementMove.bezierCurve" in osk,
          "OSK attached-edge slide must use the default-spatial motion token")
    for token in (
        "property bool _oskResident:",
        "property real _oskRevealProgress:",
        "readonly property real revealOffsetY:",
        "transform: Translate { y: oskRoot.revealOffsetY }",
        "progress: root._oskRevealProgress",
    ):
        check(token in osk,
              f"OSK must stay resident and slide through its attached edge: {token}")

    for token in (
        "tangentRevealDirection",
        "tangentAnimationOffset",
        "bodyRect.x + tangentAnimationOffset",
        "bodyRect.y + tangentAnimationOffset",
    ):
        check(token not in geometry,
              f"Connected popup slide must stay on the attachment axis like Caelestia: {token}")

    for token in (
        "id: innerCornerCanvas",
        "readonly property bool topSide:",
        "readonly property bool leftSide:",
        "onTopSideChanged: requestPaint()",
        "onLeftSideChanged: requestPaint()",
        "if (topSide && leftSide)",
        "else if (!topSide && leftSide)",
    ):
        check(token in screen_edge,
              f"Screen Edge must paint all four inner-corner orientations explicitly: {token}")
    check("ctx.scale(-1, 1)" not in screen_edge
          and "ctx.scale(1, -1)" not in screen_edge,
          "Screen Edge inner corners must not depend on first-paint mirror transforms")

    for token in (
        "id: sidebarEdgeFlares",
        "tracksBodyTranslation",
        "JoinFlares maps bodyItem through mapToItem()",
    ):
        check(token in sidebar_host,
              f"Sidebar Screen Edge shoulders must follow the mapped body once: {token}")
    sidebar_flare_start = sidebar_host.index("id: sidebarEdgeFlares")
    sidebar_flare_end = sidebar_host.index("ShellEditSurfaceFrame", sidebar_flare_start)
    sidebar_flare_block = sidebar_host[sidebar_flare_start:sidebar_flare_end]
    check("transform: Translate" not in sidebar_flare_block,
          "Sidebar flares must not double-apply the Loader translation after mapToItem()")

    media_popup = read("modules/mediaControls/BarMediaPopup.qml")
    check("EqualizerPanel {" in media_popup,
          "Bar media popup must retain the Equalizer panel")
    check("No active player" not in media_popup
          and "Make sure your player has MPRIS support" not in media_popup,
          "Bar media popup must not append an inactive-player text card below Equalizer")

    compact_sidebar = read("modules/sidebarRight/CompactSidebarRightContent.qml")
    check("import qs.modules.mediaControls" in compact_sidebar
          and "EqualizerPanel {" in compact_sidebar
          and "active: root.panelVisible" in compact_sidebar,
          "Compact right Sidebar Media section must render the shared Equalizer below the player")

    resources_popup = read("modules/bar/ResourcesPopup.qml")
    check('Translation.tr("RPM:")' in resources_popup
          and 'Translation.tr("Speed:")' not in resources_popup,
          "ThinkFan inline metric must use the compact RPM label")
    check('String(ThinkFanService.fanRpm)' in resources_popup,
          "ThinkFan RPM value must not repeat the RPM unit after the RPM label")

    for settings_path in (
        "modules/settings/SettingsOverlay.qml",
        "modules/settings/SettingsFocus.qml",
    ):
        settings_surface = read(settings_path)
        for token in (
            "import qs.modules.common.perimeter",
            "PolkitService.active ? WlrLayer.Top : WlrLayer.Overlay",
            "y: settingsPanel.height - height",
            "ConnectedSurfaceJoinFlares {",
            "joinBottom: true",
            "bottomLeftRadius: 0",
            "bottomRightRadius: 0",
        ):
            check(token in settings_surface,
                  f"{settings_path} must be a bottom-connected popup below Polkit: {token}")

    settings_overlay = read("modules/settings/SettingsOverlay.qml")
    settings_focus = read("modules/settings/SettingsFocus.qml")
    check("1600" in settings_overlay
          and "settingsPanel.width * 0.90" in settings_overlay
          and "settingsPanel.height * 0.92" in settings_overlay,
          "Rail Settings overlay must use the enlarged bottom-connected footprint")
    check("1560" in settings_focus
          and "settingsPanel.width * 0.88" in settings_focus
          and "settingsPanel.height * 0.92" in settings_focus,
          "Focus Settings overlay must use the enlarged bottom-connected footprint")
    for settings_surface in (settings_overlay, settings_focus):
        check("Appearance.animation.elementMove.duration" in settings_surface
              and "Appearance.animation.elementMove.bezierCurve" in settings_surface,
              "Connected Settings overlays must use the Caelestia-style default-spatial slide")

    dashboard = read("modules/overview/OverviewDashboard.qml")
    check("fallbackColor: Appearance.colors.colLayer0" in dashboard
          and "wallpaperBackdropEnabled: root.useWallpaperBackdrop" in dashboard
          and "readonly property bool useWallpaperBackdrop: false" in dashboard,
          "Dashboard connected body must stay on the same solid Material surface as connected popups")
    check("Appearance.animation.elementMove.duration" in dashboard
          and "Appearance.animation.elementMove.bezierCurve" in dashboard,
          "Dashboard connected slide must use the default-spatial motion token")

    critical_panels = read("modules/ii/critical/ShellIiCriticalPanels.qml")
    check('../../screenCorners/ScreenEdges.qml' in critical_panels,
          "ii critical shell must load persistent Screen Edge chrome")
    check('../../sidebar/SidebarEdgeConnectors.qml' not in critical_panels,
          "ii critical shell must not recreate the retired standalone sidebar bridge window")
    check("PerimeterRuntime.qml" not in critical_panels,
          "Full iiPerimeter runtime must not be booted by the critical shell")

    frame = read("modules/common/perimeter/ConnectedSurfaceFrame.qml")
    check("property real connectorBorderWidth: 0" in frame,
          "ConnectedSurfaceFrame must default the connector outline off at the seam")
    check("strokeWidth: root.connectorBorderWidth" in frame,
          "ConnectedSurfaceFrame must route connector outline width through its seam policy")
    check("flared connector" in frame,
          "ConnectedSurfaceFrame must preserve the flared body/connector seam contract")
    check("opacity: root.geometry.progress" not in frame,
          "ConnectedSurfaceFrame must morph geometry instead of fading the whole surface")
    check("property bool hoverEnabled: false" in frame
          and "readonly property bool bodyHovered: bodyHover.hovered" in frame
          and "HoverHandler {" in frame,
          "ConnectedSurfaceFrame must expose body-scoped hover ownership for popup hand-off")
    join_flares = read("modules/common/perimeter/ConnectedSurfaceJoinFlares.qml")
    check("component Flare: RoundCorner" in join_flares
          and "import qs.modules.common.widgets" in join_flares,
          "Connected shoulders must reuse the same RoundCorner primitive as the Hug Bar")
    check("component Flare: Canvas" not in join_flares,
          "Connected shoulders must not maintain a second Canvas corner renderer")

    mask = read("modules/common/perimeter/ConnectedSurfaceMask.qml")
    for token in ("_sourceStrip", "_middleStrip", "_bodyStrip", "connectorSourceExtent"):
        check(token in mask,
              f"ConnectedSurfaceMask must track the flared connector rather than its full bounding box: {token}")
    check("item: root.active ? root.connectorItem" not in mask,
          "ConnectedSurfaceMask must not make the transparent connector bounding box fully interactive")

    bar_runtime = read("modules/bar/Bar.qml")
    vertical_bar_runtime = read("modules/verticalBar/VerticalBar.qml")
    bar_content = read("modules/bar/BarContent.qml")
    vertical_bar_content = read("modules/verticalBar/VerticalBarContent.qml")
    for runtime in (bar_runtime, vertical_bar_runtime):
        check("readonly property bool showBarBackground: true" in runtime,
              "Supported Hug Bar chrome must remain structurally present")
        check("Appearance.animation.elementMove.duration" in runtime
              and "Appearance.animation.elementMove.bezierCurve" in runtime,
              "Bar auto-hide slide must use the default-spatial motion token")
    check("visible: !gameModeMinimal" in bar_content,
          "Horizontal Hug body must not disappear because of legacy showBackground state")
    check("visible: !root.gameModeMinimal && !root.isIslands" in vertical_bar_content,
          "Vertical Hug body must not disappear because of legacy showBackground state")
    check("Config.options?.bar?.cornerStyle" not in bar_content,
          "Horizontal Hug body must ignore persisted retired cornerStyle at runtime")
    check("Config.options?.bar?.cornerStyle" not in vertical_bar_content,
          "Vertical Hug body must ignore persisted retired cornerStyle at runtime")
    check("(Config.options?.bar?.cornerStyle ?? 0) === 0" not in vertical_bar_runtime,
          "Vertical Hug shoulders must not depend on legacy cornerStyle state")

    media = read("modules/bar/Media.qml")
    check("PopupWindow" not in media,
          "Bar Media must not restore detached PopupWindow surfaces")
    check(media.count("StyledPopup {") >= 2,
          "Bar Media wheel HUD and expanded controls must both use StyledPopup")
    check("BarMediaPopup {" in media,
          "Bar Media must preserve its expanded control content inside the connected surface")
    check("keyboardFocus: true" in media,
          "Expanded Media connected popout must preserve keyboard focus")

    taskbar_preview = read("modules/bar/BarTaskbarPreview.qml")
    check("StyledPopup {" in taskbar_preview,
          "Taskbar window previews must use the connected bar popout shell")
    check("PopupWindow {" not in taskbar_preview,
          "Taskbar window previews must not restore the detached PopupWindow shell")
    check("GlassBackground {" not in taskbar_preview,
          "Taskbar window previews must not draw a second floating card inside the connected shell")
    check("anchorItem" in taskbar_preview and "previewOpen" in taskbar_preview,
          "Taskbar preview must preserve real button anchoring and hover lifecycle")

    tray = read("modules/bar/SysTray.qml")
    check("alternativeVisibleCondition: root.trayOverflowOpen" in tray,
          "Tray overflow must use the shared connected visibility lifecycle")
    check("active: root.trayOverflowOpen" not in tray,
          "Tray overflow must not bypass the retract lifecycle by overriding LazyLoader.active")

    check(not (ROOT / "modules/bar/ClockWidgetTooltip.qml").exists(),
          "Retired ClockWidgetTooltip must not return as a standalone hover surface")

    connected_bar_popouts = {
        "modules/bar/TimerIndicatorTooltip.qml": "StyledPopup {",
        "modules/bar/ShellUpdateIndicator.qml": "StyledPopup {",
        "modules/bar/BatteryPopup.qml": "StyledPopup {",
        "modules/bar/ResourcesPopup.qml": "StyledPopup {",
    }
    for path, connected_shell in connected_bar_popouts.items():
        source = read(path)
        check(connected_shell in source,
              f"{path} must use the shared connected bar popout shell")
        check("PopupWindow" not in source,
              f"{path} must not restore a detached PopupWindow surface")

    bar_runtime = read("modules/bar/Bar.qml")
    check('Config.setNestedValue("bar.cornerStyle", 0)' in bar_runtime,
          "Classic Bar startup must normalize persisted legacy corner styles to Hug")
    config_qml = read("modules/common/Config.qml")
    defaults_json = read("defaults/config.json")
    appearance_qml = read("modules/common/Appearance.qml")
    shell_layout = read("services/ShellLayoutController.qml")
    check("property int cornerStyle: 0" in config_qml,
          "Classic Bar schema default must be Hug")
    check('"cornerStyle": 0' in defaults_json,
          "Classic Bar persisted default must be Hug")
    check("property int material: 0" in config_qml
          and '"material": 0' in defaults_json,
          "Material global-style compatibility corner must resolve to Hug")
    check("Config.options?.bar?.cornerStyle" not in appearance_qml,
          "Shared Bar sizing must not branch on retired cornerStyle")
    check("Config.options?.bar?.cornerStyle" not in shell_layout,
          "Shell layout reservation must not branch on retired cornerStyle")
    for retired_runtime_token in ("effectiveCornerStyle", "floatStyleShadow", "barFillInner"):
        check(retired_runtime_token not in bar_runtime,
              f"Classic Bar runtime must not retain retired corner-style branch: {retired_runtime_token}")

    bar_settings = read("modules/settings/BarConfigHugOnly.qml")
    quick_settings = read("modules/settings/QuickConfigHugOnly.qml")
    check('Translation.tr("Corner style")' in bar_settings
          and 'Translation.tr("Float shadow")' in bar_settings,
          "Public Bar settings must suppress retired corner-style and float-shadow controls")
    check('Translation.tr("Bar style")' in quick_settings,
          "Quick settings must suppress the retired Bar style selector")
    check("_hugUiReady" not in bar_settings
          and "opacity: root._hugUiReady" not in bar_settings
          and "onTriggered: root._applyHugOnlyUi(root)" in bar_settings,
          "Public Bar settings must remain visible while the compatibility pruning pass runs")
    check("_hugUiReady" not in quick_settings
          and "opacity: root._hugUiReady" not in quick_settings
          and "onTriggered: root._applyHugOnlyUi(root)" in quick_settings,
          "Quick settings must remain visible while the Hug compatibility pruning pass runs")
    check('Config.options?.appearance?.screenEdge?.width ?? 10' in bar_settings
          and 'Config.setNestedValue("appearance.screenEdge.width", value)' in bar_settings,
          "Bar settings must expose persistent Screen Edge width with a 10px default")

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
    check('Config.setNestedValue("bar.cornerStyle", 0)' in settings_registry,
          "Legacy Classic Bar corner styles must normalize to Hug")
    check('Config.setNestedValue("bar.showBackground", true)' in settings_registry,
          "Legacy transparent Classic Bar state must normalize to the structural Hug surface")
    check('Config.setNestedValue("sidebar.style", "panel")' in settings_registry
          and 'Config.setNestedValue("sidebar.cardStyle", false)' in settings_registry,
          "Legacy Sidebar Island/Card values must normalize to Panel/non-card")
    check('component: "modules/settings/BarConfigHugOnly.qml"' in settings_registry,
          "Public Bar settings must route through the Hug-only facade")
    bar_hug_config = read("modules/settings/BarConfigHugOnly.qml")
    check('text === Translation.tr("Show background")' in bar_hug_config,
          "Hug-only Bar settings must hide the retired transparent-background toggle")
    check('component: "modules/settings/QuickConfigHugOnly.qml"' in settings_registry,
          "Public Quick settings must route through the Hug-only facade")
    check('entry.label !== Translation.tr("Corner style")' in settings_registry,
          "Settings search must not expose the retired Bar corner-style selector")
    settings_registry_data = read("modules/settings/SettingsPageRegistryData.qml")
    check('label: Translation.tr("Bar background")' not in settings_registry_data,
          "Settings search source must not retain the retired Bar background toggle")
    check('label: Translation.tr("Sidebar style")' not in settings_registry_data,
          "Settings search source must not retain the retired Sidebar surface selector")

    sidebars_config = read("modules/settings/SidebarsConfig.qml")
    check('Translation.tr("Use Card style")' not in sidebars_config
          and 'Translation.tr("Island")' not in sidebars_config
          and 'Config.setNestedValue("sidebar.style"' not in sidebars_config,
          "Sidebar General settings must not expose Island or Card surface choices")

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
    check('Quickshell.shellPath("translations")' in translation and '/en_US.json' in translation,
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
