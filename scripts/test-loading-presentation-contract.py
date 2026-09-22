#!/usr/bin/env python3
"""Regression guard for the shared loading presentation.

Loading without a label uses a rotating gear. Loading with a label uses only
animated 'Loading', without the retired morphing shape or adjacent spinner.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


gear = read("modules/common/widgets/MaterialLoadingIndicator.qml")
label = read("modules/common/widgets/LoadingText.qml")
qmldir = read("modules/common/widgets/qmldir")
locale = read("translations/en_US.json")

for token in ('text: "settings"', "RotationAnimation on rotation",
              "property bool loading: true", "property real pullProgress: 0",
              "property real implicitSize: 48", "property color color:"):
    assert token in gear, f"gear loader contract missing {token!r}"
for retired in ("MaterialShape {", "SoftBurst", "Cookie9Sided", "leapAnimation"):
    assert retired not in gear, f"retired morphing loader remains: {retired}"
assert 'text: Translation.tr("Loading")' in label
assert "SequentialAnimation on opacity" in label
assert "SequentialAnimation on scale" in label
assert "MaterialLoadingIndicator {" not in label
assert "LoadingText 1.0 LoadingText.qml" in qmldir
assert '"Loading": "Loading"' in locale

# Task rows with a label remain text-only. Full-page navigation is
# deliberately the icon-only Floating Gear variant, without an elevated card.
task = read("modules/common/widgets/SettingsTaskLoadingState.qml")
assert "LoadingText {" in task
assert "MaterialLoadingIndicator {" not in task
assert "property string text:" not in task

page = read("modules/common/widgets/SettingsPageLoadingOverlay.qml")
assert "MaterialLoadingIndicator {" in page
assert "LoadingText {" not in page
assert "property string text:" not in page
assert "loadingLabel.implicitWidth" not in page
assert "SettingsMaterialPreset.cardColor" not in page
assert "SettingsMaterialPreset.cardRadius" not in page
assert "minimumVisibleTimer" not in page
assert "_hidePending" not in page
assert "Behavior on scale" not in page
assert "visible: root.loading && root._shown" in page
assert "root._shown = false" in page
assert 'color: "transparent"' in page
assert "border.color: SettingsMaterialPreset.accentColor" in page
assert "color: SettingsMaterialPreset.accentColor" in page
assert "anchors.centerIn: parent" in page
import re
ring = re.search(r"Item\\s*\\{\\s*anchors.centerIn: parent\\s*width: (\\d+)\\s*height: width", page)
glyph = re.search(r"MaterialLoadingIndicator\\s*\\{[^}]*implicitSize: (\\d+)", page, re.S)
assert ring and glyph, "Floating Gear must size the ring and glyph"
ring_size, indicator_size = int(ring[1]), int(glyph[1])
assert 60 <= ring_size <= 68
assert 36 <= indicator_size * 0.8 <= 40
assert "RotationAnimation on rotation" not in page, "Ring must remain static"

for path, host in (
    ("settings.qml", "pagesStack"),
    ("modules/settings/SettingsFocus.qml", "pageHost"),
    ("modules/settings/SettingsOverlay.qml", "overlayPagesHost"),
):
    content = read(path)
    assert ("loading: " + host + ".loading && !" + host + ".currentItem && !" + host + ".error") in content, path

for path in (
    "settings.qml",
    "modules/settings/SettingsFocus.qml",
    "modules/settings/SettingsOverlay.qml",
    "modules/settings/DesktopWidgetsConfig.qml",
):
    content = read(path)
    assert 'text: Translation.tr("Loading page…")' not in content, path
    assert 'text: Translation.tr("Loading section…")' not in content, path

for path in (
    "modules/sidebarLeft/news/NewsView.qml",
    "modules/sidebarLeft/animeSchedule/AnimeScheduleView.qml",
    "modules/sidebarLeft/SoftwareView.qml",
    "modules/overview/ActionModeView.qml",
    "modules/mediaControls/components/PlayerLyrics.qml",
    "modules/sidebarLeft/LocalMusicView.qml",
    "modules/sidebarLeft/YtMusicView.qml",
    "modules/sidebarLeft/plugins/WebAppView.qml",
    "modules/waffle/notificationPopup/WNotificationItem.qml",
    "modules/ii/overlay/floatingImage/FloatingImage.qml",
):
    assert "LoadingText {" in read(path), path

for path in (
    "modules/sidebarLeft/news/NewsView.qml",
    "modules/sidebarLeft/animeSchedule/AnimeScheduleView.qml",
    "modules/sidebarLeft/SoftwareView.qml",
    "modules/sidebarLeft/plugins/WebAppView.qml",
    "modules/waffle/notificationPopup/WNotificationItem.qml",
    "modules/ii/overlay/floatingImage/FloatingImage.qml",
    "waffleSettings.qml",
):
    assert 'Translation.tr("Loading...")' not in read(path), path

assert "BusyIndicator {" not in read("modules/overview/ActionModeView.qml")
waffle = read("waffleSettings.qml")
assert 'text: Translation.tr("Loading")' in waffle
assert "id: startupLoadingLabel" in waffle
assert "SequentialAnimation on opacity" in waffle
assert "SequentialAnimation on scale" in waffle

# Intentional icon-only activity (buffering, session login and update badge)
# must use a gear. Action-specific status/progress text stays available.
assert "MaterialLoadingIndicator {" in read("modules/sidebarLeft/innertune/ITPlayer.qml")
assert '"progress_activity"' not in read("modules/sidebarLeft/innertune/ITPlayer.qml")
assert 'root.loginInProgress ? "settings" : "arrow_forward"' in read("dots/sddm/pixel/Main.qml")
for path in ("modules/bar/ShellUpdateIndicator.qml",
             "modules/shellUpdate/ShellUpdateOverlay.qml"):
    assert '"progress_activity"' not in read(path), path

# Preserve non-loading icons (Preview, success, errors), but never render one
# alongside a busy/loading label in the wallpaper and encoder settings.
for path in ("modules/settings/GowallWallpaperEditor.qml",
             "modules/waffle/settings/pages/WGowallPage.qml",
             "modules/settings/ToolsConfig.qml",
             "modules/wallpaperLauncher/WallpaperLauncherContent.qml"):
    content = read(path)
    assert "LoadingText {" in content, path
    assert '"progress_activity"' not in content, path

ytmusic = read("modules/sidebarLeft/YtMusicView.qml")
assert "MaterialLoadingIndicator {" not in ytmusic
assert '"progress_activity"' not in ytmusic

print("Shared loading presentation contracts: PASS")
