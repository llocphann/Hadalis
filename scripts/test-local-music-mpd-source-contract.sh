#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

service="$root/services/LocalMusic.qml"
mpris="$root/services/MprisController.qml"
view="$root/modules/sidebarLeft/LocalMusicView.qml"
sidebar="$root/modules/sidebarLeft/SidebarLeftContent.qml"
editor="$root/modules/common/widgets/SidebarLayoutEditor.qml"
defaults="$root/defaults/config.json"
schema="$root/modules/common/Config.qml"
registry="$root/modules/settings/SettingsPageRegistryData.qml"

grep -Fq 'local_music_mpd.py' "$service" || fail 'LocalMusic must use MPD helper'
grep -Fq 'readonly property var mprisPlayer: MprisController.mpdPlayer' "$service" || fail 'LocalMusic must use MPD MPRIS player'
grep -Fq 'MprisController.ensureMpdMprisBridge(mpdHost, mpdPort)' "$service" || fail 'LocalMusic must request MPRIS for its configured MPD endpoint'
grep -Fq 'property MprisPlayer mpdPlayer: null' "$mpris" || fail 'MprisController must expose MPD player'
grep -Fq 'org.mpris.MediaPlayer2.mpd.hadalis' "$mpris" || fail 'custom MPD endpoints need a dedicated Hadalis MPRIS instance'
grep -Fq '_mpdMprisCustomProc.command = root._mpdCustomBridgeCommand()' "$mpris" || fail 'custom MPD endpoint must launch endpoint-bound mpd-mpris'
grep -Fq 'command: ["/usr/bin/systemctl", "--user", "start", "mpd-mpris.service"]' "$mpris" || fail 'default localhost MPD must retain distro mpd-mpris service path'
grep -Fq 'LocalMusic.updateDatabase()' "$view" || fail 'Music UI must expose MPD update'
grep -Fq 'PlayerControl {' "$view" || fail 'Music now-playing UI must reuse Media popup PlayerControl'
grep -Fq 'id: nowPlayingPanel' "$view" || fail 'Music media must live above its section tabs'
grep -Fq 'id: classicPlaybackOptions' "$view" || fail 'Music must retain the compact transport-adjacent volume row'
grep -Fq 'Layout.preferredWidth: 100' "$view" || fail 'Music volume slider width drifted'
grep -Fq 'configuration: StyledSlider.Configuration.XS' "$view" || fail 'Music volume slider must keep the thin XS track'
grep -Fq 'playbackAdapter: localMusicPlayerAdapter' "$view" || fail 'Music PlayerControl must retain direct MPD fallback state/actions'
if grep -Fq 'symbol: LocalMusic.shuffleMode ? "shuffle_on" : "shuffle"' "$view"; then
    fail 'Music must not duplicate Shuffle below PlayerControl'
fi
if grep -Fq 'symbol: LocalMusic.repeatMode === 1' "$view"; then
    fail 'Music must not duplicate Repeat below PlayerControl'
fi
grep -Fq 'player: LocalMusic.mprisPlayer' "$view" || fail 'Music PlayerControl must bind the MPD MPRIS session when available'
grep -Fq 'model: LocalMusic.playlists' "$view" || fail 'Playlists tab must expose saved MPD playlists only'
grep -Fq 'property var selectedTrackKeys: []' "$view" || fail 'Songs must expose desktop bulk selection state'
grep -Fq 'property var selectedFolderPaths: []' "$view" || fail 'Songs must expose folder bulk selection state'
grep -Fq 'function selectFolder(folder, entryIndex, modifiers): void' "$view" || fail 'Songs folders must support bulk selection semantics'
grep -Fq 'root.isFolderSelected(modelData.path)' "$view" || fail 'Folder delegates must render their selected state'
grep -Fq 'Qt.ControlModifier' "$view" || fail 'Songs must support Ctrl multi-selection'
grep -Fq 'Qt.ShiftModifier' "$view" || fail 'Songs must support Shift range selection'
grep -Fq 'function createPlaylist(name: string, tracks): void' "$service" || fail 'LocalMusic must support creating saved MPD playlists'
grep -Fq 'function addTracksToPlaylist(name: string, tracks): void' "$service" || fail 'LocalMusic must support adding tracks to MPD playlists'
grep -Fq 'client.command("playlistadd", playlist_name, uri)' "$root/scripts/local_music_mpd.py" || fail 'MPD helper must mutate saved playlists with playlistadd'
grep -Fq 'Layout.fillHeight: false' "$view" || fail 'Music search must not consume the song viewport'
grep -Fq 'ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }' "$view" || fail 'Music lists must expose scrolling'
grep -Fq 'Translation.tr("Lyrics")' "$view" || fail 'Music must expose the local Lyrics tab'
grep -Fq 'local_music_lyrics.py' "$service" || fail 'LocalMusic must load local sidecar lyrics'
grep -Fq 'function removeQueueTrack(index: int): void' "$service" || fail 'Music Queue must expose per-track MPD removal'
grep -Fq 'function clearQueue(): void' "$service" || fail 'Music Queue must expose MPD clear'
grep -Fq '"deleteid",' "$root/scripts/local_music_mpd.py" || fail 'MPD helper must allow stable queue-id deletion'
grep -Fq '"clear",' "$root/scripts/local_music_mpd.py" || fail 'MPD helper must allow clearing the active queue'
grep -Fq 'removable: true' "$view" || fail 'Queue rows must expose their remove action'
grep -Fq 'onRemoveRequested: LocalMusic.removeQueueTrack(index)' "$view" || fail 'Queue remove UI must target MPD queue state'
grep -Fq 'onClicked: LocalMusic.clearQueue()' "$view" || fail 'Queue must expose a Clear action'
grep -Fq 'id: clearQueueContent' "$view" || fail 'Queue Clear must keep a combined icon/text content group'
grep -Fq 'anchors.centerIn: parent' "$view" || fail 'Queue Clear icon/text group must be centered'
grep -Fq 'implicitHeight: 50' "$view" || fail 'Song/queue rows must retain compact desktop-player density'
grep -Fq 'def binary(self, name: str, uri: str)' "$root/scripts/local_music_mpd.py" || fail 'MPD helper must read binary artwork without a private player backend'
grep -Fq 'for command in ("albumart", "readpicture")' "$root/scripts/local_music_mpd.py" || fail 'Music covers must prefer MPD albumart and fall back to embedded readpicture'
grep -Fq '_populate_library_art(client, tracks)' "$root/scripts/local_music_mpd.py" || fail 'MPD library snapshot must hydrate cover art'
grep -Fq '.resolve().as_uri()' "$root/scripts/local_music_mpd.py" || fail 'local cover paths must be emitted as QML-safe file URLs'
grep -Fq 'id: coverImage' "$view" || fail 'Song rows must render their resolved cover image'
grep -Fq 'visible: coverImage.status !== Image.Ready' "$view" || fail 'Song rows must keep a fallback icon until cover decoding succeeds'
if grep -Eq 'mpvPath|local_music_ipc|local_music_scan|--input-ipc-server' "$service"; then
    fail 'LocalMusic must not regress to a private mpv player'
fi
[[ ! -e "$root/scripts/local_music_ipc.py" ]] \
    || fail 'retired private mpv IPC helper must stay removed'
[[ ! -e "$root/scripts/local_music_scan.py" ]] \
    || fail 'retired filesystem scanner must stay removed; MPD owns the library database'
grep -Fq '"wallhaven", "news", "music", "tools", "software"' "$schema" \
    || fail 'canonical sidebar schema order must use music instead of ytmusic'
grep -Fq '"music"' "$defaults" \
    || fail 'default sidebar order must contain the canonical music id'
grep -Fq 'leftDefaultOrder: ["widgets", "ai", "translator", "anime", "animeSchedule", "wallhaven", "news", "music", "tools", "software"]' "$editor" \
    || fail 'Sidebar layout editor must arrange the canonical Music tab'
grep -Fq 'id === "ytmusic" ? "music" : id' "$editor" \
    || fail 'Sidebar layout editor must normalize legacy ytmusic order ids'
grep -Fq 'Component { id: musicComp; LocalMusicView {} }' "$sidebar" \
    || fail 'Left Sidebar must route Music to LocalMusicView'
if grep -Fq 'label: Translation.tr("YT Music Up Next notifications")' "$registry"; then
    fail 'retired YT Music notification settings must not remain searchable'
fi
if grep -Fq 'label: Translation.tr("YT Music fullscreen suppression")' "$registry"; then
    fail 'retired YT Music fullscreen settings must not remain searchable'
fi
printf 'PASS: Local Music is MPD-owned with MPRIS transport integration\n'
