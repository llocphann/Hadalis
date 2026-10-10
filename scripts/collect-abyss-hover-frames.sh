#!/usr/bin/env bash
# Read-only bounded owner-session diagnostics. No shell restart, config write,
# remap, privilege, audio access, filesystem scan, or continuous background job.
set -uo pipefail

if ! command -v qs >/dev/null 2>&1; then
    printf 'qs (Quickshell) is unavailable; do not interpret as a test PASS.\n' >&2
    exit 127
fi
qs_cmd=(qs)
if [[ -n "${HADALIS_QS_CONFIG:-}" ]]; then
    qs_cmd+=(-c "$HADALIS_QS_CONFIG")
fi
output_dir="${1:-${TMPDIR:-/tmp}/hadalis-abyss-hover-$(date +%Y%m%d-%H%M%S)}"
mkdir -p -- "$output_dir" || exit 1
{
    printf 'capture_utc=%s\n' "$(date -u +%FT%TZ)"
    printf 'git_HEAD=%s\n' "$(git rev-parse HEAD 2>/dev/null || printf unavailable)"
    printf 'git_branch=%s\n' "$(git branch --show-current 2>/dev/null || printf unavailable)"
    printf 'qs_binary=%s\n' "$(command -v qs)"
    printf 'qs_config=%s\n' "${HADALIS_QS_CONFIG:-auto}"
    printf 'capture=6s frame-only, then 40 bounded hover samples at 150ms\n'
    printf 'caveat=source checkout SHA is not proof of installed shell identity\n'
} > "$output_dir/identity.txt"

# Phase 1: trigger panel/Popup open/close/reversal on the intended output.
# No 150ms IPC poll is mixed into the frame-interval sampling window.
if ! "${qs_cmd[@]}" ipc call abyssHoverProbe startFrames > "$output_dir/frame-start.txt" 2>&1; then
    printf 'Could not start frame probe; see %s/frame-start.txt\n' "$output_dir" >&2
    exit 1
fi
sleep 6
if ! "${qs_cmd[@]}" ipc call abyssHoverProbe stopFrames > "$output_dir/frame-intervals.txt" 2>&1; then
    printf 'Frame probe stop failed; inspect %s/frame-intervals.txt\n' "$output_dir" >&2
    exit 1
fi

# Phase 2: slowly cross the Popup/Screen Edge seam, then move to empty desktop.
# The snapshots capture lease/mask state, never private clipboard/notes contents.
failed=0
for ((i=0; i<40; i++)); do
    printf 'sample=%02d utc=%s\n' "$i" "$(date -u +%FT%T.%3NZ)" >> "$output_dir/hover-snapshots.log"
    if ! "${qs_cmd[@]}" ipc call abyssHoverProbe snapshot >> "$output_dir/hover-snapshots.log" 2>&1; then
        printf 'error=cannot_call_snapshot\n' >> "$output_dir/hover-snapshots.log"
        failed=$((failed + 1))
    fi
    sleep .15
done
printf 'snapshot_failures=%d\n' "$failed" >> "$output_dir/identity.txt"
printf 'Diagnostic folder: %s\n' "$output_dir"
printf 'Provide identity.txt, frame-intervals.txt and hover-snapshots.log for diagnosis.\n'
if ((failed>0)); then exit 2; fi
