#!/usr/bin/env bash
# Launch the isolated Hadalis U1 config. This never starts/restarts the production inir config.
set -euo pipefail

here="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -s "$here/U1Surface.qsb" ]]; then
    "$here/build-shader.sh"
fi

quickshell_bin="${QUICKSHELL:-}"
if [[ -z "$quickshell_bin" ]]; then
    if command -v quickshell >/dev/null 2>&1; then
        quickshell_bin="$(command -v quickshell)"
    elif command -v qs >/dev/null 2>&1; then
        quickshell_bin="$(command -v qs)"
    else
        printf 'quickshell/qs was not found in PATH\n' >&2
        exit 2
    fi
fi

exec "$quickshell_bin" -p "$here" --no-color
