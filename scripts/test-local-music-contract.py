#!/usr/bin/env python3
"""Source contract for the Left Sidebar local Music replacement."""

from __future__ import annotations
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")

def require(source: str, token: str, message: str) -> None:
    if token not in source:
        raise SystemExit(message)

def forbid(source: str, token: str, message: str) -> None:
    if token in source:
        raise SystemExit(message)

service = read("services/LocalMusic.qml")
view = read("modules/sidebarLeft/LocalMusicView.qml")
sidebar = read("modules/sidebarLeft/SidebarLeftContent.qml")
settings = read("modules/settings/SidebarsConfig.qml")
service_qmldir = read("services/qmldir")
sidebar_qmldir = read("modules/sidebarLeft/qmldir")
config = read("modules/common/Config.qml")
defaults = json.loads(read("defaults/config.json"))
scanner = read("scripts/local_music_scan.py")
ipc = read("scripts/local_music_ipc.py")

require(service_qmldir, "singleton LocalMusic 1.0 LocalMusic.qml",
        "LocalMusic must be registered as a service singleton.")
require(sidebar_qmldir, "LocalMusicView 1.0 LocalMusicView.qml",
        "LocalMusicView must be exported by the Left Sidebar module.")
require(config, "property JsonObject music: JsonObject {",
        "Config schema must expose sidebar.music.")
music_defaults = defaults.get("sidebar", {}).get("music", {})
if music_defaults.get("enable") is not False or "libraryFolder" not in music_defaults:
    raise SystemExit("default config must expose disabled sidebar.music with a libraryFolder.")
left_order = defaults.get("sidebar", {}).get("left", {}).get("tabOrder", [])
if "music" not in left_order or "ytmusic" in left_order:
    raise SystemExit("default Left Sidebar tab order must use the canonical music id.")

for token in (
    'readonly property bool enabled: Config.options?.sidebar?.music?.enable ?? false',
    'Directories.scriptsPath + "/local_music_scan.py"',
    'Directories.scriptsPath + "/local_music_ipc.py"',
    '"--input-ipc-server=" + ipcSocket',
    'function playCollection(collection, index = 0): void',
    'function toggleShuffle(): void',
    'function cycleRepeatMode(): void',
):
    require(service, token, f"LocalMusic backend contract missing: {token}")
for forbidden in ("yt-dlp", "youtube.com", "InnerTube", "YtMusic"):
    forbid(service, forbidden, f"LocalMusic backend must remain local-only: {forbidden}")

for token in (
    'property alias inputField: searchField',
    'Translation.tr("Songs")',
    'Translation.tr("Playlists")',
    'Translation.tr("Queue")',
    'FolderDialog {',
    'FileDialog {',
    'LocalMusic.playCollection',
    'LocalMusic.playPath',
    'LocalMusic.seek',
):
    require(view, token, f"Local Music frontend contract missing: {token}")
for forbidden in ("YtMusic", "InnerTune", "yt-dlp", "youtube"):
    forbid(view, forbidden, f"Local Music frontend must not route online playback: {forbidden}")

require(sidebar, 'property bool musicEnabled: Config.options?.sidebar?.music?.enable ?? false',
        "Left Sidebar must gate the Music tab with sidebar.music.enable.")
require(sidebar, 'Component { id: musicComp; LocalMusicView {} }',
        "Left Sidebar must load LocalMusicView for the music tab.")
require(sidebar, 'savedId === "ytmusic" ? "music" : savedId',
        "legacy saved YT tab ordering must map to the local Music tab.")
require(sidebar, 'values["sidebar.ytmusic.enable"] = false',
        "legacy enabled YT state must be retired during Music migration.")
for forbidden in ('Translation.tr("YT Music")', "InnerTuneView {}"):
    forbid(sidebar, forbidden, f"Left Sidebar still exposes retired YT UI: {forbidden}")

require(settings, 'text: Translation.tr("Music")',
        "Sidebar Settings must expose Music.")
require(settings, 'Config.setNestedValue("sidebar.music.enable", checked)',
        "Sidebar Settings Music switch must use canonical sidebar.music state.")
require(settings, 'LocalMusic.setLibraryFolder(String(selectedFolder))',
        "Sidebar Settings must choose the local library folder through LocalMusic.")
for forbidden in ('Translation.tr("YT Music")', "sidebar.ytmusic.autoConnect",
                  "sidebar.ytmusic.audioQuality", "sidebar.ytmusic.upNextNotifications"):
    forbid(settings, forbidden, f"Sidebar Settings still exposes YT-specific controls: {forbidden}")

for token in ('PLAYLIST_EXTENSIONS = {".m3u",".m3u8"}', '"kind":"folder"', "AUDIO_EXTENSIONS"):
    require(scanner, token, f"local library scanner contract missing: {token}")
for token in ('socket.AF_UNIX', '"playlist-pos"', 'mode == "watch"', 'mode == "command"'):
    require(ipc, token, f"local mpv IPC helper contract missing: {token}")

print("Local Music source contract: OK")
