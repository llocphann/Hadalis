#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
script="$repo_root/scripts/colors/apply-chrome-theme.sh"

fail() {
  printf 'chrome theme no-op preferences guard failed: %s\n' "$1" >&2
  exit 1
}

function_block="$(sed -n '/^fix_preferences() {$/,/^}$/p' "$script")"
[[ -n "$function_block" ]] || fail 'fix_preferences helper is missing'
grep -Fq 'def inir_theme_ready($wanted):' <<<"$function_block" \
  || fail 'semantic no-op guard is missing'
grep -Fq 'if inir_theme_ready($cs) then' <<<"$function_block" \
  || fail 'jq must skip replacement output when owned fields already match'

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
prefs_dir="$work/profile"
prefs="$prefs_dir/Default/Preferences"
mkdir -p "$(dirname "$prefs")"

# Source the production helper without executing apply-chrome-theme.sh main().
eval 'log() { :; }'
eval "$function_block"

printf '%s\n' '{"extensions":{"theme":{"id":"","use_system":false,"use_custom":false}},"browser":{"theme":{"color_scheme":2,"color_scheme2":2}},"unrelated":{"keep":"verbatim"}}' > "$prefs"
before="$(<"$prefs")"
before_inode="$(stat -c %i "$prefs")"
fix_preferences "$prefs_dir" fixture 2
[[ "$(<"$prefs")" == "$before" ]] || fail 'already-correct Preferences must remain byte-identical'
[[ "$(stat -c %i "$prefs")" == "$before_inode" ]] || fail 'already-correct Preferences must not be replaced'
[[ ! -e "$prefs.ii-tmp" ]] || fail 'no-op temporary Preferences file leaked'

jq '.browser.theme.color_scheme = 1 | .browser.theme.user_color = "#123456"' "$prefs" > "$prefs.changed"
mv "$prefs.changed" "$prefs"
fix_preferences "$prefs_dir" fixture 2
jq -e '
  .extensions.theme.id == "" and
  .extensions.theme.use_system == false and
  .extensions.theme.use_custom == false and
  .browser.theme.color_scheme == 2 and
  .browser.theme.color_scheme2 == 2 and
  ((.browser.theme | has("user_color")) | not) and
  .unrelated.keep == "verbatim"
' "$prefs" >/dev/null || fail 'drifted owned fields were not reconciled'

missing_dir="$work/missing"
fix_preferences "$missing_dir" fixture 1
jq -e '
  .extensions.theme.id == "" and
  .extensions.theme.use_system == false and
  .extensions.theme.use_custom == false and
  .browser.theme.color_scheme == 1 and
  .browser.theme.color_scheme2 == 1
' "$missing_dir/Default/Preferences" >/dev/null || fail 'missing Preferences bootstrap semantics changed'

printf 'chrome theme no-op preferences guards: ok\n'
