#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
binds="$repo_root/defaults/niri/config.d/70-binds.kdl"
migration="$repo_root/sdata/migrations/040-niri-inir-keybind-path.sh"

fail() {
    printf 'FAIL: Niri keybind launcher contract: %s\n' "$1" >&2
    exit 1
}

[[ -f "$binds" ]] || fail 'missing managed Niri bind file'
[[ -f "$migration" ]] || fail 'missing launcher-path migration'

# Bare spawn depends entirely on the compositor PATH. Developer installs place
# inir in XDG_BIN_HOME, which is not guaranteed to be present in Niri's PATH.
if grep -Fq 'spawn "inir"' "$binds"; then
    fail 'managed Niri binds still use PATH-dependent bare spawn "inir"'
fi

wrapper='spawn "/bin/sh" "-c" "PATH=\"${XDG_BIN_HOME:-$HOME/.local/bin}:$PATH\"; exec inir \"$@\"" "inir-keybind"'
grep -Fq "$wrapper" "$binds" \
    || fail 'managed Niri binds do not use the XDG_BIN_HOME-aware launcher wrapper'
grep -Fq 'Mod+Q repeat=false' "$binds" \
    || fail 'Mod+Q close-window binding is missing'
grep -Fq '"close-window"; }' "$binds" \
    || fail 'Mod+Q no longer routes to the close-window command'

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

# The migration must repair existing modular configs and be idempotent.
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
