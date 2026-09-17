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
        "|| root.popupHovered",
        "enabled: root.active",
    ):
        check(token in styled_popup, f"StyledPopup must preserve connected-perimeter contract: {token}")
    for edge in ("top", "bottom", "left", "right"):
        check(f'"{edge}"' in styled_popup,
              f"StyledPopup must preserve {edge} attachment handling")
    check("Appearance.colors.colSurfaceContainer" not in styled_popup,
          "Connected bar popups must use the owning bar surface family, not the detached popup-card material")
    check("active: root.requestedVisible || root._lingerVisible" in styled_popup,
          "Connected popout loader must stay resident long enough to retract into the bar")
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
        "connectorRectForBody",
        "animatedBodyRect",
    ):
        check(token in geometry,
              f"ConnectedSurfaceGeometry missing seam/morph geometry contract: {token}")

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

    frame = read("modules/common/perimeter/ConnectedSurfaceFrame.qml")
    check("property real connectorBorderWidth: 0" in frame,
          "ConnectedSurfaceFrame must default the connector outline off at the seam")
    check("strokeWidth: root.connectorBorderWidth" in frame,
          "ConnectedSurfaceFrame must route connector outline width through its seam policy")
    check("flared connector" in frame,
          "ConnectedSurfaceFrame must preserve the flared body/connector seam contract")
    check("opacity: root.geometry.progress" not in frame,
          "ConnectedSurfaceFrame must morph geometry instead of fading the whole surface")

    mask = read("modules/common/perimeter/ConnectedSurfaceMask.qml")
    for token in ("_sourceStrip", "_middleStrip", "_bodyStrip", "connectorSourceExtent"):
        check(token in mask,
              f"ConnectedSurfaceMask must track the flared connector rather than its full bounding box: {token}")
    check("item: root.active ? root.connectorItem" not in mask,
          "ConnectedSurfaceMask must not make the transparent connector bounding box fully interactive")

    media_surface = read("modules/perimeter/MediaConnectedSurface.qml")
    weather_surface = read("modules/perimeter/WeatherConnectedSurface.qml")
    for path, source in (
        ("modules/perimeter/MediaConnectedSurface.qml", media_surface),
        ("modules/perimeter/WeatherConnectedSurface.qml", weather_surface),
    ):
        check("ConnectedSurfaceContentHost {" in source,
              f"{path} must use the shared connected content host")
        check("geometry.offsetX" not in source and "geometry.offsetY" not in source,
              f"{path} must not reference retired connected geometry offsets")

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

    connected_bar_popouts = {
        "modules/bar/ClockWidgetTooltip.qml": "StyledPopup {",
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
    check("_hugUiReady" in bar_settings and "_hugUiReady" in quick_settings,
          "Hug-only settings facades must prune retired controls before first paint")

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
    check('component: "modules/settings/BarConfigHugOnly.qml"' in settings_registry,
          "Public Bar settings must route through the Hug-only facade")
    check('component: "modules/settings/QuickConfigHugOnly.qml"' in settings_registry,
          "Public Quick settings must route through the Hug-only facade")
    check('entry.label !== Translation.tr("Corner style")' in settings_registry,
          "Settings search must not expose the retired Bar corner-style selector")

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
