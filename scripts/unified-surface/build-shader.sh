#!/usr/bin/env bash
# Developer-only U1 shader baker. No package installation, download, or runtime compilation.
set -euo pipefail

here="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
src="$here/U1Surface.frag"
out="$here/U1Surface.qsb"
tmp="$out.tmp"

find_qsb() {
    if [[ -n "${QSB:-}" && -x "${QSB}" ]]; then
        printf '%s\n' "$QSB"
        return 0
    fi
    local candidate
    for candidate in qsb qsb-qt6 /usr/lib/qt6/bin/qsb /usr/lib/qt6/libexec/qsb pyside6-qsb; do
        if command -v "$candidate" >/dev/null 2>&1; then
            command -v "$candidate"
            return 0
        fi
        if [[ -x "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    return 1
}

qsb="$(find_qsb || true)"
if [[ -z "$qsb" ]]; then
    printf '%s\n' \
        'U1 shader bake requires Qt Shader Tools qsb.' \
        'Arch: install qt6-shadertools.' \
        'Debian/Ubuntu: install qt6-shader-baker (or the distro package providing qsb).' >&2
    exit 2
fi

rm -f "$tmp"
trap 'rm -f "$tmp"' EXIT

# qsb always embeds SPIR-V. U1 additionally targets modern Linux OpenGL profiles;
# this avoids relying on legacy GLSL ES 100 derivative extensions for fwidth().
"$qsb" --glsl "300es,330" -o "$tmp" "$src"
"$qsb" -d "$tmp" > "$tmp.reflect"

for uniform in smoothK frameRadius popupRadius effectRect frameOuter frameInner popupRect materialColor; do
    grep -Fq "$uniform" "$tmp.reflect" || {
        printf 'qsb reflection is missing expected uniform: %s\n' "$uniform" >&2
        exit 3
    }
done

mv "$tmp" "$out"
rm -f "$tmp.reflect"
trap - EXIT
printf 'Baked %s with %s\n' "$out" "$("$qsb" --version 2>&1 | head -1)"
sha256sum "$out"
