#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
migration="$repo_root/sdata/migrations/054-retire-ytmusic-web-plugin.sh"
scan="$repo_root/scripts/scan-plugins.py"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

[[ ! -e "$repo_root/defaults/plugins/music" ]] \
  || fail 'retired YouTube Music default plugin must not be shipped'
grep -Fq 'Retired plugins are removed by migrations' "$scan" \
  || fail 'plugin bootstrap must document retired-plugin behavior'
! grep -Fqi 'YouTube Music' "$scan" \
  || fail 'plugin bootstrap must not advertise the retired YouTube Music default'
[[ -f "$migration" ]] || fail 'YTMusic web-plugin retirement migration is missing'

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export XDG_CONFIG_HOME="$tmp/config"
mkdir -p "$XDG_CONFIG_HOME/inir/plugins/music"
cat > "$XDG_CONFIG_HOME/inir/plugins/music/manifest.json" <<'JSON'
{
  "id": "music",
  "name": "YouTube Music",
  "url": "https://music.youtube.com",
  "icon": "library_music",
  "version": "1.0",
  "display": "tab",
  "userscripts": ["scripts/adblock.js", "scripts/sponsorblock.js"]
}
JSON

# shellcheck disable=SC1090
source "$migration"
migration_check || fail 'migration must detect the exact shipped YTMusic plugin'
migration_apply
[[ ! -e "$XDG_CONFIG_HOME/inir/plugins/music" ]] \
  || fail 'migration must remove the exact shipped YTMusic plugin'

mkdir -p "$XDG_CONFIG_HOME/inir/plugins/music"
cat > "$XDG_CONFIG_HOME/inir/plugins/music/manifest.json" <<'JSON'
{
  "id": "music",
  "name": "My custom music portal",
  "url": "https://example.invalid/music",
  "version": "1.0",
  "display": "tab"
}
JSON
if migration_check; then
  fail 'migration must not classify a custom music plugin as retired YTMusic'
fi
migration_apply
[[ -f "$XDG_CONFIG_HOME/inir/plugins/music/manifest.json" ]] \
  || fail 'migration must preserve custom music plugins'

echo 'retired YTMusic web-plugin contract passed'
