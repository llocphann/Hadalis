#!/usr/bin/env bash
# Compare the committed QSB with a fresh bake by extracted shader semantics.
# QShader package serialization itself is not byte-deterministic on Qt 6.4.
set -euo pipefail

here="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
canonical="$here/U1Surface.qsb"

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

[[ -s "$canonical" ]] || {
    printf 'committed U1Surface.qsb is missing or empty\n' >&2
    exit 2
}

qsb="$(find_qsb || true)"
[[ -n "$qsb" ]] || {
    printf 'Qt Shader Tools qsb is required to verify U1Surface.qsb\n' >&2
    exit 2
}

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
cp "$canonical" "$tmpdir/committed.qsb"

"$here/build-shader.sh" >/dev/null
cp "$canonical" "$tmpdir/rebuilt.qsb"

# Reflection is JSON; normalize key ordering before comparison.
"$qsb" -x reflect -o "$tmpdir/committed.reflect.json" "$tmpdir/committed.qsb"
"$qsb" -x reflect -o "$tmpdir/rebuilt.reflect.json" "$tmpdir/rebuilt.qsb"
python3 - "$tmpdir/committed.reflect.json" "$tmpdir/rebuilt.reflect.json" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    committed = json.load(handle)
with open(sys.argv[2], encoding="utf-8") as handle:
    rebuilt = json.load(handle)
if committed != rebuilt:
    raise SystemExit("QSB reflection differs from fresh bake")
PY

# Compare the executable shader payloads, not the nondeterministic QSB container.
for spec in "spirv,100" "glsl,300es" "glsl,330"; do
    safe="${spec//,/__}"
    "$qsb" -x "$spec" -o "$tmpdir/committed.$safe" "$tmpdir/committed.qsb"
    "$qsb" -x "$spec" -o "$tmpdir/rebuilt.$safe" "$tmpdir/rebuilt.qsb"
    cmp "$tmpdir/committed.$safe" "$tmpdir/rebuilt.$safe" || {
        printf 'QSB executable payload differs for %s\n' "$spec" >&2
        exit 3
    }
done

printf 'U1 QSB semantic package verification: PASS (%s)\n' "$("$qsb" --version 2>&1 | head -1)"
