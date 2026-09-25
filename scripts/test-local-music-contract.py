#!/usr/bin/env python3
"""Source contract for the Left Sidebar MPD/MPRIS Music player."""
from __future__ import annotations
import importlib.util
import json
import subprocess
import sys
import tempfile
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
config = read("modules/common/Config.qml")
defaults = json.loads(read("defaults/config.json"))
mpd = read("scripts/local_music_mpd.py")
lyrics = read("scripts/local_music_lyrics.py")
dispatch = read("scripts/native-dispatch")

require(config, "property JsonObject music: JsonObject {", "Config must expose sidebar.music.")
music_defaults = defaults.get("sidebar", {}).get("music", {})
for key in ("enable", "libraryFolder", "mpdHost", "mpdPort"):
    if key not in music_defaults:
        raise SystemExit(f"default config missing sidebar.music.{key}")
left_order = defaults.get("sidebar", {}).get("left", {}).get("tabOrder", [])
if "music" not in left_order or "ytmusic" in left_order:
    raise SystemExit("default Left Sidebar order must use music.")

for token in (
    'readonly property string nativeDispatchPath: Directories.scriptsPath + "/native-dispatch"',
    'root.nativeDispatchPath, "mpd", "snapshot",',
    'root.nativeDispatchPath, "mpd", "status",',
    'root.nativeDispatchPath, "mpd-daemon",',
    'root.nativeDispatchPath, "mpd-subscribe",',
    'property bool _mpdSubscriptionEligible: false',
    'if (event.payload && typeof event.payload === "object")',
    'function _scheduleStatusFallback(): void',
    '_lyricsProc.command = [root.nativeDispatchPath, "lyrics", path]',
    'readonly property var mprisPlayer: MprisController.mpdPlayer',
    'MprisController.ensureMpdMprisBridge(mpdHost, mpdPort)',
    'property var localLyricsLines: []',
    'readonly property int localLyricsActiveIndex:',
    'function enqueueTracks(tracks): void',
    'function createPlaylist(name: string, tracks): void',
    'function addTracksToPlaylist(name: string, tracks): void',
):
    require(service, token, f"LocalMusic backend contract missing: {token}")
for forbidden in ("yt-dlp", "youtube.com", "InnerTube", "YtMusic", "--input-ipc-server"):
    forbid(service, forbidden, f"LocalMusic backend must remain MPD/local-only: {forbidden}")

for token in (
    'python_exec "$ROOT_DIR/scripts/local_music_mpd.py" "$@"',
    'python_exec "$ROOT_DIR/scripts/local_music_mpd.py" subscribe "$@"',
    'python_exec "$ROOT_DIR/scripts/local_music_lyrics.py" "$track"',
):
    require(dispatch, token, f"native selector must retain reversible Python fallback: {token}")

for token in (
    'def subscribe(host: str, port: int, override_root: str) -> int:',
    'client.command("idle", *IDLE_SUBSYSTEMS)',
    '"type": "subscribed"',
    '"type": "changed"',
):
    require(mpd, token, f"Python MPD event fallback contract missing: {token}")

for token in (
    'Translation.tr("Songs")',
    'Translation.tr("Playlists")',
    'Translation.tr("Queue")',
    'Translation.tr("Lyrics")',
    'Layout.fillHeight: false',
    'ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }',
    'PlayerControl {',
    'id: nowPlayingPanel',
    'player: LocalMusic.mprisPlayer',
    'visualizerPoints: localMusicCava.points',
    'LocalMusic.localLyricsLines',
    'readonly property var songEntries: root.buildSongEntries()',
    'property var selectedTrackKeys: []',
    'property var selectedFolderPaths: []',
    'function selectFolder(folder, entryIndex, modifiers): void',
    'root.isFolderSelected(modelData.path)',
    'Qt.ControlModifier',
    'Qt.ShiftModifier',
    'model: LocalMusic.playlists',
    'ContextMenu {',
    'LocalMusic.createPlaylist(name, root.pendingPlaylistTracks)',
    'LocalMusic.addTracksToPlaylist(name, snapshot)',
    'id: classicPlaybackOptions',
    'Layout.preferredWidth: 100',
    'configuration: StyledSlider.Configuration.XS',
    'playbackAdapter: localMusicPlayerAdapter',
    'LocalMusic.toggleShuffle()',
    'LocalMusic.cycleRepeatMode()',
    'LocalMusic.setVolume(value)',
    'id: clearQueueContent',
    'anchors.centerIn: parent',
):
    require(view, token, f"Local Music frontend contract missing: {token}")
for forbidden in ("YtMusic", "InnerTune", "yt-dlp", "youtube"):
    forbid(view, forbidden, f"Local Music frontend must stay local-only: {forbidden}")

if "model: LocalMusic.collections" in view:
    raise SystemExit("Playlists must contain only saved MPD playlists, not folder collections.")
if 'symbol: LocalMusic.shuffleMode ? "shuffle_on" : "shuffle"' in view:
    raise SystemExit("Local Music must not duplicate Shuffle below the shared PlayerControl.")
if "symbol: LocalMusic.repeatMode === 1" in view:
    raise SystemExit("Local Music must not duplicate Repeat below the shared PlayerControl.")
if view.index("id: nowPlayingPanel") > view.index('model: ['):
    raise SystemExit("Now-playing media must render above the Music section tabs.")

require(sidebar, 'Component { id: musicComp; LocalMusicView {} }',
        "Left Sidebar must load LocalMusicView.")
require(settings, 'Config.setNestedValue("sidebar.music.enable", checked)',
        "Sidebar Settings must use canonical Music state.")

for token in ('client.command("listallinfo")', 'client.command("listplaylists")',
              'client.command("playlistinfo")', "def replace_queue(",
              'client.command("playlistadd", playlist_name, uri)',
              'def _load_json_list_argument(value: str)',
              'if mode in ("playlist-create", "playlist-add")',
              'if mode == "enqueue-many"'):
    require(mpd, token, f"MPD library contract missing: {token}")
for token in ("STAMP_RE", 'track.with_suffix(".lrc")',
              'track.with_suffix(".txt")', '"synced": synced'):
    require(lyrics, token, f"local lyrics helper missing: {token}")

with tempfile.TemporaryDirectory() as tmp:
    root = Path(tmp)
    track = root / "song.flac"
    track.touch()
    (root / "song.lrc").write_text(
        "[00:01.00][00:02.50]First line\n[00:04.00]Second line\n",
        encoding="utf-8",
    )
    raw = subprocess.check_output(
        [sys.executable, str(ROOT / "scripts/local_music_lyrics.py"), str(track)],
        text=True,
    )
    payload = json.loads(raw)
    if payload.get("status") != "ok" or payload.get("synced") is not True:
        raise SystemExit("local lyrics helper did not recognize synchronized LRC.")
    if [round(float(line["time"]), 2) for line in payload["lines"]] != [1.0, 2.5, 4.0]:
        raise SystemExit("local lyrics timestamp parsing regressed.")

spec = importlib.util.spec_from_file_location("hadalis_local_music_mpd", ROOT / "scripts/local_music_mpd.py")
if spec is None or spec.loader is None:
    raise SystemExit("could not import local_music_mpd helper")
mpd_helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mpd_helper)

with tempfile.TemporaryDirectory() as tmp:
    payload_path = Path(tmp) / "bulk-selection.json"
    bulk_uris = [
        f"Artist {i:04d}/Album {i:04d}/" + ("track-" + "x" * 72) + f"-{i:04d}.flac"
        for i in range(3000)
    ]
    encoded = json.dumps(bulk_uris)
    if len(encoded.encode("utf-8")) <= 131072:
        raise SystemExit("bulk payload fixture must exceed Linux's common per-argument limit")
    payload_path.write_text(encoded, encoding="utf-8")
    loaded = mpd_helper._load_json_list_argument("@" + str(payload_path))
    if loaded != bulk_uris:
        raise SystemExit("file-backed MPD bulk payload transport corrupted the selection")
    if mpd_helper._load_json_list_argument(json.dumps(["a.flac", "b.flac"])) != ["a.flac", "b.flac"]:
        raise SystemExit("inline MPD JSON payload compatibility regressed")

print("Local Music MPD/MPRIS + local lyrics source contract: OK")
