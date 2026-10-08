#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
service="$root/services/LocalMusic.qml"
helper="$root/scripts/local_music_mpd.py"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

# The Dashboard native test verifies selection versus double-click activation.
# This check retains the MPD append/play protocol and stable-id routing.
grep -Fq 'function enqueueTrack(track, playNow = true): void' "$service" \
    || fail 'LocalMusic must expose append-to-MPD-queue behavior'
grep -Fq 'root.nativeDispatchPath, "mpd", "enqueue"' "$service" \
    || fail 'LocalMusic enqueue must route through the selectable MPD backend without replacing the queue'
grep -Fq 'client.command("addid", uri)' "$helper" \
    || fail 'MPD enqueue must append without clearing the queue'
grep -Fq 'client.command("playid", song_id)' "$helper" \
    || fail 'double-click play must target the exact appended MPD song id'
grep -Fq 'if mode == "enqueue"' "$helper" \
    || fail 'MPD helper must expose enqueue mode'

printf 'Local Music double-click queue contracts: PASS\n'
