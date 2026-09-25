#!/usr/bin/env bash
set -euo pipefail

copy=true
if [[ "${1:-}" == "--no-copy" ]]; then
    copy=false
    shift
fi
if (($# > 0)); then
    printf 'Usage: %s [--no-copy]\n' "${0##*/}" >&2
    exit 2
fi

if command -v hyprpicker >/dev/null 2>&1; then
    # hyprpicker is wlroots-compatible and provides a useful magnifier. Its name
    # is historical; using it here does not enable a Hyprland compositor path.
    args=(--format=hex --no-fancy)
    $copy && args+=(--autocopy)
    exec hyprpicker "${args[@]}"
fi

for command_name in grim slurp magick; do
    command -v "$command_name" >/dev/null 2>&1 || {
        printf 'colorpicker: missing required command: %s\n' "$command_name" >&2
        exit 1
    }
done

geometry="$(slurp -p)"
[[ -n "$geometry" ]] || exit 1
hex="$(grim -g "$geometry" -t ppm -     | magick ppm:- -depth 8 -format '%[hex:p{0,0}]' info:- 2>/dev/null)"
hex="${hex:0:6}"
[[ "$hex" =~ ^[[:xdigit:]]{6}$ ]] || {
    printf 'colorpicker: could not decode sampled pixel\n' >&2
    exit 1
}
color="#${hex^^}"

if $copy && command -v wl-copy >/dev/null 2>&1; then
    printf '%s' "$color" | wl-copy
fi
printf '%s\n' "$color"
