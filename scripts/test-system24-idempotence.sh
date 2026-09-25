#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
generator="$repo_root/scripts/colors/system24_palette.py"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT

fail() {
    printf 'system24 idempotence regression failed: %s\n' "$1" >&2
    exit 1
}

palette="$tmp/app-palette.json"
system24="$tmp/system24.theme.css"
midnight="$tmp/inir-midnight.theme.css"
tui="$tmp/inir-tui.theme.css"

cat > "$palette" <<'JSON'
{
  "primary": "#7aa2f7",
  "secondary": "#bb9af7",
  "tertiary": "#9ece6a",
  "error": "#f7768e",
  "surface": "#1a1b26",
  "surface_container_low": "#20212d",
  "surface_container": "#242532",
  "surface_container_high": "#292b3a",
  "surface_container_highest": "#303244",
  "outline": "#565f89",
  "on_surface": "#c0caf5",
  "on_surface_variant": "#a9b1d6",
  "on_primary": "#16161e"
}
JSON

run_generator() {
    QUICKSHELL_PALETTE_JSON="$palette" \
    QUICKSHELL_RAW_PALETTE_JSON="$tmp/missing-palette.json" \
    QUICKSHELL_COLORS_JSON="$tmp/missing-colors.json" \
    SYSTEM24_PALETTE_CSS="$system24" \
    MIDNIGHT_DMS_CSS="$midnight" \
    INIR_TUI_CSS="$tui" \
    python3 "$generator" >/dev/null
}

snapshot() {
    python3 - "$system24" "$midnight" "$tui" <<'PY'
import hashlib
import os
import sys

for path in sys.argv[1:]:
    with open(path, "rb") as handle:
        digest = hashlib.sha256(handle.read()).hexdigest()
    print(f"{path}|{os.stat(path).st_mtime_ns}|{digest}")
PY
}

run_generator
for output in "$system24" "$midnight" "$tui"; do
    [[ -s "$output" ]] || fail "missing generated output: $output"
done

first_snapshot="$(snapshot)"
sleep 0.05
run_generator
second_snapshot="$(snapshot)"
[[ "$second_snapshot" == "$first_snapshot" ]] \
    || fail 'unchanged palette rewrote one or more System24 outputs'

original_hash="$(python3 - "$system24" <<'PY'
import hashlib
import sys
with open(sys.argv[1], "rb") as handle:
    print(hashlib.sha256(handle.read()).hexdigest())
PY
)"
printf '\n/* manual edit */\n' >> "$system24"
sleep 0.05
run_generator
reconciled_hash="$(python3 - "$system24" <<'PY'
import hashlib
import sys
with open(sys.argv[1], "rb") as handle:
    print(hashlib.sha256(handle.read()).hexdigest())
PY
)"
[[ "$reconciled_hash" == "$original_hash" ]] \
    || fail 'manual output drift was not reconciled'

printf 'system24 idempotence guards: ok\n'
