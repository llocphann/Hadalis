#!/usr/bin/env bash
set -euo pipefail

here="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
out_dir="${HADALIS_IRIS_POC_CAPTURE_DIR:-$here/captures}"
warmup="${HADALIS_IRIS_POC_CAPTURE_WARMUP:-0.35}"
mode="${HADALIS_IRIS_POC_MODE:-card-owner}"
profile="${HADALIS_IRIS_POC_PROFILE:-diagnostic}"
output="${HADALIS_IRIS_POC_OUTPUT:-}"

if [[ -z "${WAYLAND_DISPLAY:-}" || -z "${XDG_RUNTIME_DIR:-}" ]]; then
    printf 'capture-matrix.sh requires an existing Wayland session.\n' >&2
    exit 2
fi
if ! command -v grim >/dev/null 2>&1; then
    printf 'Missing grim; install it before capturing the visual matrix.\n' >&2
    exit 127
fi

if [[ -n "${QS:-}" ]]; then
    qs_bin="$QS"
elif command -v qs >/dev/null 2>&1; then
    qs_bin="$(command -v qs)"
elif command -v quickshell >/dev/null 2>&1; then
    qs_bin="$(command -v quickshell)"
else
    printf 'Missing Quickshell executable (qs/quickshell).\n' >&2
    exit 127
fi

mkdir -p "$out_dir"
manifest="$out_dir/manifest.tsv"
printf 'edge\tsource_t\tmode\tprofile\tpng\tlog\n' > "$manifest"

current_pid=""
cleanup() {
    if [[ -n "$current_pid" ]] && kill -0 "$current_pid" 2>/dev/null; then
        kill "$current_pid" 2>/dev/null || true
        wait "$current_pid" 2>/dev/null || true
    fi
    current_pid=""
}
trap cleanup EXIT INT TERM

capture_case() {
    local edge="$1"
    local source_t="$2"
    local safe_t="${source_t/./p}"
    local stem="${edge}-${safe_t}-${mode}-${profile}"
    local png="$out_dir/$stem.png"
    local log="$out_dir/$stem.log"

    printf 'capture %-6s source=%s mode=%s profile=%s\n' "$edge" "$source_t" "$mode" "$profile"

    HADALIS_IRIS_POC_EDGE="$edge" \
    HADALIS_IRIS_POC_SOURCE_T="$source_t" \
    HADALIS_IRIS_POC_MODE="$mode" \
    HADALIS_IRIS_POC_PROFILE="$profile" \
    HADALIS_IRIS_POC_OUTPUT="$output" \
    HADALIS_IRIS_POC_GUIDES=1 \
        "$qs_bin" -n -p "$here" >"$log" 2>&1 &
    current_pid=$!

    local ready=0
    for _ in $(seq 1 80); do
        if grep -Fq 'HADALIS_IRIS_POC' "$log" 2>/dev/null; then
            ready=1
            break
        fi
        if ! kill -0 "$current_pid" 2>/dev/null; then
            printf 'PoC exited before readiness marker for %s/%s.\n' "$edge" "$source_t" >&2
            cat "$log" >&2 || true
            return 1
        fi
        sleep 0.05
    done
    if [[ "$ready" -ne 1 ]]; then
        printf 'Timed out waiting for PoC readiness marker for %s/%s.\n' "$edge" "$source_t" >&2
        cat "$log" >&2 || true
        return 1
    fi

    sleep "$warmup"
    if [[ -n "$output" ]]; then
        grim -o "$output" "$png"
    else
        grim "$png"
    fi

    printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$edge" "$source_t" "$mode" "$profile" "$png" "$log" >> "$manifest"

    cleanup
}

for edge in top bottom left right; do
    for source_t in 0.02 0.50 0.98; do
        capture_case "$edge" "$source_t"
    done
done

contact="$out_dir/contact-sheet-${mode}-${profile}.png"
images=(
    "$out_dir/top-0p02-${mode}-${profile}.png"
    "$out_dir/top-0p50-${mode}-${profile}.png"
    "$out_dir/top-0p98-${mode}-${profile}.png"
    "$out_dir/bottom-0p02-${mode}-${profile}.png"
    "$out_dir/bottom-0p50-${mode}-${profile}.png"
    "$out_dir/bottom-0p98-${mode}-${profile}.png"
    "$out_dir/left-0p02-${mode}-${profile}.png"
    "$out_dir/left-0p50-${mode}-${profile}.png"
    "$out_dir/left-0p98-${mode}-${profile}.png"
    "$out_dir/right-0p02-${mode}-${profile}.png"
    "$out_dir/right-0p50-${mode}-${profile}.png"
    "$out_dir/right-0p98-${mode}-${profile}.png"
)

if command -v magick >/dev/null 2>&1; then
    magick montage "${images[@]}" -tile 3x4 -geometry '640x360+8+8' "$contact"
    printf 'contact sheet: %s\n' "$contact"
elif command -v montage >/dev/null 2>&1; then
    montage "${images[@]}" -tile 3x4 -geometry '640x360+8+8' "$contact"
    printf 'contact sheet: %s\n' "$contact"
else
    printf 'ImageMagick not found; 12 individual captures are available in %s\n' "$out_dir"
fi

printf 'manifest: %s\n' "$manifest"
