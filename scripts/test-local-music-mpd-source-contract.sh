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
