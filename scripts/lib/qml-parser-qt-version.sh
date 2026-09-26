#!/usr/bin/env bash
set -euo pipefail

parser="${1:-}"
[[ -n "$parser" ]] || { printf 'usage: %s <qmlformat-path>\n' "$0" >&2; exit 2; }

resolve_cmd() {
    local candidate="$1"
    if [[ "$candidate" == /* ]]; then
        [[ -x "$candidate" ]] && printf '%s\n' "$candidate"
    else
        command -v "$candidate" 2>/dev/null || true
    fi
}

extract_version() {
    grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1
}

parser_path="$(resolve_cmd "$parser")"
[[ -n "$parser_path" ]] || exit 1
parser_dir="$(cd -- "$(dirname -- "$parser_path")" && pwd -P)"

# qmlformat's own --version may be the formatter's tool version (for example
# "qmlformat 1.0"), not the Qt runtime version. Prefer Qt installation tools.
for candidate in     "$parser_dir/qtpaths6" "$parser_dir/qtpaths"     qtpaths6 qtpaths
do
    resolved="$(resolve_cmd "$candidate")"
    [[ -n "$resolved" ]] || continue
    version="$("$resolved" --qt-version 2>/dev/null | extract_version || true)"
    if [[ -n "$version" ]]; then
        printf '%s\n' "$version"
        exit 0
    fi
done

for candidate in     "$parser_dir/qmake6" "$parser_dir/qmake"     qmake6 qmake
do
    resolved="$(resolve_cmd "$candidate")"
    [[ -n "$resolved" ]] || continue
    version="$("$resolved" -query QT_VERSION 2>/dev/null | extract_version || true)"
    if [[ -n "$version" ]]; then
        printf '%s\n' "$version"
        exit 0
    fi
done

# Some distributions report the Qt version directly from qmlformat. Accept that
# only when it looks like a Qt major version, never a tool-local 1.x version.
version="$("$parser_path" --version 2>&1 | extract_version || true)"
if [[ -n "$version" ]]; then
    major="${version%%.*}"
    if (( major >= 5 )); then
        printf '%s\n' "$version"
        exit 0
    fi
fi

exit 1
