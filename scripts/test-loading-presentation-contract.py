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

for path in (
    "modules/common/widgets/SettingsTaskLoadingState.qml",
    "modules/common/widgets/SettingsPageLoadingOverlay.qml",
):
    content = read(path)
    assert "LoadingText {" in content, path
    assert "MaterialLoadingIndicator {" not in content, path
    assert "property string text:" not in content, path

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

print("Shared loading presentation contracts: PASS")
