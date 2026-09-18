#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
view="$root/modules/sidebarLeft/LocalMusicView.qml"
service="$root/services/LocalMusic.qml"
helper="$root/scripts/local_music_mpd.py"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

grep -Fq 'onDoubleClicked: trackRow.activated()' "$view" \
    || fail 'song rows must activate on double click'
if grep -Fq 'onClicked: trackRow.activated()' "$view"; then
    fail 'single click must not preempt the double-click queue action'
fi
grep -Fq 'onActivated: LocalMusic.enqueueTrack(modelData, true)' "$view" \
    || fail 'Songs double click must append and play through LocalMusic.enqueueTrack'
grep -Fq 'function enqueueTrack(track, playNow = true): void' "$service" \
    || fail 'LocalMusic must expose append-to-MPD-queue behavior'
grep -Fq '"python3", _mpdScript, "enqueue"' "$service" \
    || fail 'LocalMusic enqueue must use the MPD helper instead of replacing the queue'
grep -Fq 'client.command("addid", uri)' "$helper" \
    || fail 'MPD enqueue must append without clearing the queue'
grep -Fq 'client.command("playid", song_id)' "$helper" \
    || fail 'double-click play must target the exact appended MPD song id'
grep -Fq 'if mode == "enqueue"' "$helper" \
    || fail 'MPD helper must expose enqueue mode'

printf 'Local Music double-click queue contracts: PASS\n'
