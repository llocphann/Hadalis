#!/usr/bin/env bash
# Read-only bounded owner-session diagnostics. No shell restart, config write,
# remap, privilege, audio access, or continuous background job.
set -uo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
output_dir="${1:-${TMPDIR:-/tmp}/hadalis-abyss-hover-$(date +%Y%m%d-%H%M%S)}"
mkdir -p -- "$output_dir" || exit 1
if ! command -v qs >/dev/null 2>&1; then
    printf 'qs unavailable; no runtime test performed.\n' | tee "$output_dir/config-error.txt" >&2
    exit 127
fi

# The production launcher (scripts/inir) targets a *path*: qs -p DIR ipc call.
# Bare qs ipc call instead looks for a nonexistent "default" config. Resolve
# the live inir path to avoid targeting a stale install or a different shell.
candidates=()
if [[ -n "${HADALIS_QS_CONFIG:-}" ]]; then
    candidates+=("$HADALIS_QS_CONFIG")
else
    if command -v jq >/dev/null 2>&1; then
        while IFS= read -r qml; do
            [[ -n "$qml" ]] && candidates+=("${qml%/shell.qml}")
        done < <(qs list --all --json 2>/dev/null | jq -r '
            .[] | (.config_path // .configPath // empty)
            | select(type=="string" and endswith("/shell.qml"))
        ' 2>/dev/null)
    fi
    while IFS= read -r qml; do
        [[ -n "$qml" ]] && candidates+=("${qml%/shell.qml}")
    done < <(qs list --all 2>/dev/null | sed -n 's/^[[:space:]]*Config path:[[:space:]]*//p' | grep '/shell\.qml
    candidates+=("${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/inir"
        "$repo_root" /usr/local/share/quickshell/inir /usr/share/quickshell/inir)
fi

resolved_config=""
for candidate in "${candidates[@]}"; do
    [[ -n "$candidate" ]] || continue
    if [[ "$candidate" == */shell.qml ]]; then candidate="${candidate%/shell.qml}"; fi
    [[ -f "$candidate/shell.qml" ]] || continue
    # An unrelated Quickshell config must never receive the diagnostics.
    grep -q '^//@ pragma ShellId inir' "$candidate/shell.qml" || continue
    canonical="$(realpath -e -- "$candidate" 2>/dev/null || printf '%s' "$candidate")"
    listing="$(qs -p "$canonical" list 2>/dev/null)" || continue
    [[ -n "$listing" && "$listing" != No\ running\ instances* ]] || continue
    resolved_config="$canonical"
    break
done
if [[ -z "$resolved_config" ]]; then
    {
        printf 'ERROR: no running iNiR Quickshell instance found.\n'
        printf 'Inspect: qs list --all\n'
        printf 'Optional: HADALIS_QS_CONFIG=/path/to/running/inir\n'
        printf 'No shell was started or changed by this script.\n'
    } | tee "$output_dir/config-error.txt" >&2
    exit 3
fi
qs_cmd=(qs -p "$resolved_config")

{
    printf 'capture_utc=%s\n' "$(date -u +%FT%TZ)"
    printf 'git_HEAD=%s\n' "$(git -C "$repo_root" rev-parse HEAD 2>/dev/null || printf unavailable)"
    printf 'git_branch=%s\n' "$(git -C "$repo_root" branch --show-current 2>/dev/null || printf unavailable)"
    printf 'qs_binary=%s\n' "$(command -v qs)"
    printf 'qs_config_requested=%s\n' "${HADALIS_QS_CONFIG:-auto}"
    printf 'qs_config_resolved=%s\n' "$resolved_config"
    installed_sha="$(git -C "$resolved_config" rev-parse HEAD 2>/dev/null || true)"
    printf 'installed_git_HEAD=%s\n' "${installed_sha:-unavailable}"
    for rel in shell.qml modules/abyss/AbyssPerimeter.qml modules/abyss/looks/AbyssGeometry.js; do
        if [[ -f "$resolved_config/$rel" && -f "$repo_root/$rel" ]]; then
            if cmp -s -- "$resolved_config/$rel" "$repo_root/$rel"; then
                printf 'installed_vs_checkout[%s]=MATCH\n' "$rel"
            else
                printf 'installed_vs_checkout[%s]=DIFFERENT\n' "$rel"
            fi
        else
            printf 'installed_vs_checkout[%s]=MISSING\n' "$rel"
        fi
    done
    printf 'capture=6s frame-only, then 40 bounded hover snapshots at 150ms spacing\n'
    printf 'caveat=source checkout SHA is not proof of installed shell identity\n'
} > "$output_dir/identity.txt"

# Phase 1: open/close/reverse the panel on the intended output while frame
# samples are enabled. Do not interleave IPC polling into this window.
if ! "${qs_cmd[@]}" ipc call abyssHoverProbe startFrames > "$output_dir/frame-start.txt" 2>&1; then
    printf 'Failed startFrames. Check %s/frame-start.txt and installed/checkout parity.\n' "$output_dir" >&2
    exit 1
fi
sleep 6
if ! "${qs_cmd[@]}" ipc call abyssHoverProbe stopFrames > "$output_dir/frame-intervals.txt" 2>&1; then
    printf 'Failed stopFrames. Check %s/frame-intervals.txt.\n' "$output_dir" >&2
    exit 1
fi

# Phase 2: cross the Popup/Screen Edge seam, then enter empty desktop.
# Snapshots are boolean state and geometry only, not user content.
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
printf 'Share identity.txt, frame-intervals.txt and hover-snapshots.log for diagnosis.\n'
if ((failed>0)); then exit 2; fi
 || true)
    candidates+=("${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/inir"
        "$repo_root" /usr/local/share/quickshell/inir /usr/share/quickshell/inir)
fi

resolved_config=""
for candidate in "${candidates[@]}"; do
    [[ -n "$candidate" ]] || continue
    if [[ "$candidate" == */shell.qml ]]; then candidate="${candidate%/shell.qml}"; fi
    [[ -f "$candidate/shell.qml" ]] || continue
    # An unrelated Quickshell config must never receive the diagnostics.
    grep -q '^//@ pragma ShellId inir' "$candidate/shell.qml" || continue
    canonical="$(realpath -e -- "$candidate" 2>/dev/null || printf '%s' "$candidate")"
    listing="$(qs -p "$canonical" list 2>/dev/null)" || continue
    [[ -n "$listing" && "$listing" != No\ running\ instances* ]] || continue
    resolved_config="$canonical"
    break
done
if [[ -z "$resolved_config" ]]; then
    {
        printf 'ERROR: no running iNiR Quickshell instance found.\n'
        printf 'Inspect: qs list --all\n'
        printf 'Optional: HADALIS_QS_CONFIG=/path/to/running/inir\n'
        printf 'No shell was started or changed by this script.\n'
    } | tee "$output_dir/config-error.txt" >&2
    exit 3
fi
qs_cmd=(qs -p "$resolved_config")

{
    printf 'capture_utc=%s\n' "$(date -u +%FT%TZ)"
    printf 'git_HEAD=%s\n' "$(git -C "$repo_root" rev-parse HEAD 2>/dev/null || printf unavailable)"
    printf 'git_branch=%s\n' "$(git -C "$repo_root" branch --show-current 2>/dev/null || printf unavailable)"
    printf 'qs_binary=%s\n' "$(command -v qs)"
    printf 'qs_config_requested=%s\n' "${HADALIS_QS_CONFIG:-auto}"
    printf 'qs_config_resolved=%s\n' "$resolved_config"
    installed_sha="$(git -C "$resolved_config" rev-parse HEAD 2>/dev/null || true)"
    printf 'installed_git_HEAD=%s\n' "${installed_sha:-unavailable}"
    for rel in shell.qml modules/abyss/AbyssPerimeter.qml modules/abyss/looks/AbyssGeometry.js; do
        if [[ -f "$resolved_config/$rel" && -f "$repo_root/$rel" ]]; then
            if cmp -s -- "$resolved_config/$rel" "$repo_root/$rel"; then
                printf 'installed_vs_checkout[%s]=MATCH\n' "$rel"
            else
                printf 'installed_vs_checkout[%s]=DIFFERENT\n' "$rel"
            fi
        else
            printf 'installed_vs_checkout[%s]=MISSING\n' "$rel"
        fi
    done
    printf 'capture=6s frame-only, then 40 bounded hover snapshots at 150ms spacing\n'
    printf 'caveat=source checkout SHA is not proof of installed shell identity\n'
} > "$output_dir/identity.txt"

# Phase 1: open/close/reverse the panel on the intended output while frame
# samples are enabled. Do not interleave IPC polling into this window.
if ! "${qs_cmd[@]}" ipc call abyssHoverProbe startFrames > "$output_dir/frame-start.txt" 2>&1; then
    printf 'Failed startFrames. Check %s/frame-start.txt and installed/checkout parity.\n' "$output_dir" >&2
    exit 1
fi
sleep 6
if ! "${qs_cmd[@]}" ipc call abyssHoverProbe stopFrames > "$output_dir/frame-intervals.txt" 2>&1; then
    printf 'Failed stopFrames. Check %s/frame-intervals.txt.\n' "$output_dir" >&2
    exit 1
fi

# Phase 2: cross the Popup/Screen Edge seam, then enter empty desktop.
# Snapshots are boolean state and geometry only, not user content.
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
printf 'Share identity.txt, frame-intervals.txt and hover-snapshots.log for diagnosis.\n'
if ((failed>0)); then exit 2; fi
