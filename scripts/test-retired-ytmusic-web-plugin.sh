#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
config_migration="$repo_root/sdata/migrations/053-retire-ytmusic.sh"
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
[[ -f "$config_migration" ]] || fail 'YTMusic config retirement migration is missing'
[[ -f "$migration" ]] || fail 'YTMusic web-plugin retirement migration is missing'

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export XDG_CONFIG_HOME="$tmp/config-migration"
mkdir -p "$XDG_CONFIG_HOME/inir"
cat > "$XDG_CONFIG_HOME/inir/config.json" <<'JSON'
{
  "sidebar": {
    "music": {
      "enable": false,
      "libraryFolder": "/keep/music"
    },
    "ytmusic": {
      "enable": true,
      "volume": 0.7
    },
    "left": {
      "tabOrder": ["ai", "ytmusic", "music", "tools", "ytmusic"]
    }
  }
}
JSON

# shellcheck disable=SC1090
source "$config_migration"
migration_check || fail 'config migration must detect retired sidebar.ytmusic state'
migration_apply
jq -e '.sidebar.music.enable == true' "$XDG_CONFIG_HOME/inir/config.json" >/dev/null   || fail 'config migration must carry enabled YTMusic state into local Music'
jq -e '.sidebar.music.libraryFolder == "/keep/music"' "$XDG_CONFIG_HOME/inir/config.json" >/dev/null   || fail 'config migration must preserve existing local Music settings'
jq -e '(.sidebar | has("ytmusic")) | not' "$XDG_CONFIG_HOME/inir/config.json" >/dev/null   || fail 'config migration must remove the retired sidebar.ytmusic subtree'
jq -e '.sidebar.left.tabOrder == ["ai", "music", "tools"]' "$XDG_CONFIG_HOME/inir/config.json" >/dev/null   || fail 'config migration must normalize and deduplicate ytmusic tab ids'
if migration_check; then
  fail 'config migration must be idempotent after retired state is removed'
fi

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

theme_migration="$repo_root/sdata/migrations/055-retire-ytmusic-theming.sh"
[[ -f "$theme_migration" ]] || fail 'YTMusic theming retirement migration is missing'
for retired in "$repo_root/scripts/colors/modules/80-pear-desktop.sh" "$repo_root/scripts/colors/pear-css-inject.py" "$repo_root/scripts/colors/targets/pear-desktop.json"; do
  [[ ! -e "$retired" ]] || fail "retired YTMusic theming artifact still shipped: $retired"
done
! grep -Fq 'enablePearDesktop' "$repo_root/modules/common/Config.qml" || fail 'retired Pear Desktop config key remains in QML schema'
! grep -Fq 'enablePearDesktop' "$repo_root/defaults/config.json" || fail 'retired Pear Desktop config key remains in default config'

export HOME="$tmp/home"; export XDG_CONFIG_HOME="$tmp/theme-config"; export XDG_STATE_HOME="$tmp/theme-state"
mkdir -p "$HOME/.local/share/applications" "$XDG_CONFIG_HOME/inir" "$XDG_CONFIG_HOME/YouTube Music" "$XDG_STATE_HOME/quickshell/user/generated"
printf '%s\n' '{"appearance":{"wallpaperTheming":{"enablePearDesktop":true,"enableChrome":true}}}' > "$XDG_CONFIG_HOME/inir/config.json"
css="$XDG_STATE_HOME/quickshell/user/generated/pear-desktop-theme.css"; printf 'retired css\n' > "$css"
printf '{"options":{"themes":["%s","/keep.css"]}}\n' "$css" > "$XDG_CONFIG_HOME/YouTube Music/config.json"
printf '%s\n' '[Desktop Entry]' 'Name=YouTube Music' 'Exec=youtube-music --remote-debugging-port=9223 %U' > "$HOME/.local/share/applications/youtube-music.desktop"
printf '%s\n' '[Desktop Entry]' 'Name=Pear Desktop' 'Exec=pear-desktop --remote-debugging-port=9222 %U' > "$HOME/.local/share/applications/pear-desktop.desktop"
printf '%s\n' '[Desktop Entry]' 'Name=Spotify' 'Exec=spotify --remote-debugging-port=9222 %U' > "$HOME/.local/share/applications/spotify.desktop"
# shellcheck disable=SC1090
source "$theme_migration"
migration_check || fail 'theming migration must detect retired Hadalis YTMusic state'
migration_apply
! jq -e '.appearance.wallpaperTheming | has("enablePearDesktop")' "$XDG_CONFIG_HOME/inir/config.json" >/dev/null || fail 'theming migration must remove enablePearDesktop'
jq -e '.appearance.wallpaperTheming.enableChrome == true' "$XDG_CONFIG_HOME/inir/config.json" >/dev/null || fail 'theming migration must preserve unrelated wallpaper theming config'
jq -e '.options.themes == ["/keep.css"]' "$XDG_CONFIG_HOME/YouTube Music/config.json" >/dev/null || fail 'theming migration must remove only the Hadalis-generated YTMusic CSS'
[[ ! -e "$css" ]] || fail 'theming migration must remove generated YTMusic CSS'
grep -Fq 'Exec=youtube-music %U' "$HOME/.local/share/applications/youtube-music.desktop" || fail 'theming migration must remove the newer YTMusic CDP flag'
grep -Fq 'Exec=pear-desktop %U' "$HOME/.local/share/applications/pear-desktop.desktop" || fail 'theming migration must remove the legacy Pear Desktop CDP flag'
grep -Fq 'Exec=spotify --remote-debugging-port=9222 %U' "$HOME/.local/share/applications/spotify.desktop" || fail 'theming migration must not touch unrelated Spotify CDP state'

for active_file in \
  "$repo_root/services/AppSearch.qml" \
  "$repo_root/modules/settings/SidebarsConfig.qml" \
  "$repo_root/modules/bar/BarTaskbarButton.qml" \
  "$repo_root/modules/dock/DockAppButton.qml" \
  "$repo_root/scripts/cava/resolve_audio_source.py"; do
  ! grep -Eqi 'ytmusic|youtube[ _-]?music|music\.youtube\.com|com\.github\.th_ch\.youtube_music|pear-desktop' "$active_file" \
    || fail "retired YTMusic special-case remains in active runtime: $active_file"
done
! grep -Fq 'music.youtube.com' "$repo_root/services/MprisController.qml" \
  || fail 'redundant YTMusic-specific streaming URL special-case remains'
! grep -Fq 'yt-dlp' "$repo_root/docs/PACKAGES.md" \
  || fail 'retired YTMusic extractor dependency remains documented'
! grep -Eqi 'YouTube Music|YT Music|music\.youtube\.com|yt-dlp|ytmusicapi' "$repo_root/translations/en_US.json" \
  || fail 'retired YTMusic translation strings remain'

echo 'retired YTMusic runtime, plugin, theming, and packaging contracts passed'
