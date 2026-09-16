#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
root_config="$repo_root/defaults/niri/config.kdl"
binds="$repo_root/defaults/niri/config.d/70-binds.kdl"
overrides="$repo_root/defaults/niri/config.d/75-inir-launcher-binds.kdl"
migration="$repo_root/sdata/migrations/040-niri-inir-keybind-path.sh"

fail() {
    printf 'FAIL: Niri keybind launcher contract: %s\n' "$1" >&2
    exit 1
}

for file in "$root_config" "$binds" "$overrides" "$migration"; do
    [[ -f "$file" ]] || fail "missing ${file#"$repo_root/"}"
done

# Niri evaluates included fragments in order. The path-safe iNiR bindings must
# override the managed 70-binds entries while 90-user-extra remains last so user
# customizations retain final precedence.
python3 - "$root_config" <<'PY'
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text(encoding="utf-8")
needles = [
    'include "config.d/70-binds.kdl"',
    'include "config.d/75-inir-launcher-binds.kdl"',
    'include "config.d/80-layer-rules.kdl"',
    'include "config.d/90-user-extra.kdl"',
]
pos = [text.find(needle) for needle in needles]
if any(value < 0 for value in pos):
    raise SystemExit("FAIL: Niri launcher override include chain is incomplete")
if pos != sorted(pos):
    raise SystemExit("FAIL: Niri launcher override include order is incorrect")
PY

wrapper='spawn "/bin/sh" "-c" "PATH=\"${XDG_BIN_HOME:-$HOME/.local/bin}:$PATH\"; exec inir \"$@\"" "inir-keybind"'
if grep -Fq 'spawn "inir"' "$overrides"; then
    fail 'launcher override file contains a PATH-dependent bare spawn "inir"'
fi
grep -Fq "$wrapper" "$overrides" \
    || fail 'launcher override file does not use the XDG_BIN_HOME-aware wrapper'
grep -Fq 'Mod+Q repeat=false' "$overrides" \
    || fail 'Mod+Q close-window override is missing'
grep -Fq '"close-window"; }' "$overrides" \
    || fail 'Mod+Q no longer routes to the close-window command'

# Keep the override layer mechanically equivalent to every managed iNiR binding
# in 70-binds.kdl. This catches newly-added launcher-backed shortcuts that would
# otherwise reintroduce the same compositor-PATH failure.
python3 - "$binds" "$overrides" <<'PY'
from pathlib import Path
import sys

base = Path(sys.argv[1]).read_text(encoding="utf-8").splitlines()
overrides = Path(sys.argv[2]).read_text(encoding="utf-8").splitlines()
wrapper = 'spawn "/bin/sh" "-c" "PATH=\\"${XDG_BIN_HOME:-$HOME/.local/bin}:$PATH\\"; exec inir \\"$@\\"" "inir-keybind"'

def norm(line: str) -> str:
    return " ".join(line.strip().split())

expected = {
    norm(line.replace('spawn "inir"', wrapper))
    for line in base
    if 'spawn "inir"' in line and not line.lstrip().startswith("//")
}
actual = {
    norm(line)
    for line in overrides
    if wrapper in line and not line.lstrip().startswith("//")
}
missing = sorted(expected - actual)
extra = sorted(actual - expected)
if missing or extra:
    details = []
    if missing:
        details.append("missing overrides: " + " | ".join(missing))
    if extra:
        details.append("unexpected overrides: " + " | ".join(extra))
    raise SystemExit("FAIL: iNiR launcher bind parity drift: " + "; ".join(details))
if not expected:
    raise SystemExit("FAIL: no managed iNiR binds were discovered in 70-binds.kdl")
PY

# Exercise the exact shell lookup semantics with a deliberately restricted PATH.
# This proves the wrapper can find a developer launcher in ~/.local/bin even when
# the compositor environment itself cannot resolve `inir`.
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
mkdir -p "$tmp/home/.local/bin"
cat > "$tmp/home/.local/bin/inir" <<'SH'
#!/bin/sh
printf '%s\n' "$*"
SH
chmod +x "$tmp/home/.local/bin/inir"

result="$(HOME="$tmp/home" XDG_BIN_HOME= PATH=/usr/bin:/bin /bin/sh -c \
    'PATH="${XDG_BIN_HOME:-$HOME/.local/bin}:$PATH"; exec inir "$@"' \
    inir-keybind close-window)"
[[ "$result" == 'close-window' ]] \
    || fail 'fallback launcher lookup did not resolve ~/.local/bin/inir'

# Existing installs do not receive defaults wholesale. The required migration
# repairs their modular 70-binds file in place and must be idempotent.
fixture="$tmp/config/niri/config.d/70-binds.kdl"
mkdir -p "$(dirname -- "$fixture")"
printf '%s\n' 'binds {' '  Mod+Q repeat=false { spawn "inir" "close-window"; }' '}' > "$fixture"
(
    export HOME="$tmp/home"
    export XDG_CONFIG_HOME="$tmp/config"
    export STY_RED='' STY_GREEN='' STY_RST=''
    # shellcheck source=/dev/null
    source "$migration"
    migration_check || fail 'migration does not detect a bare launcher bind'
    migration_apply
    ! migration_check || fail 'migration is not idempotent after repair'
)

grep -Fq "$wrapper" "$fixture" \
    || fail 'migration did not install the robust launcher wrapper'

printf 'PASS: Niri keybind launcher lookup contracts\n'
