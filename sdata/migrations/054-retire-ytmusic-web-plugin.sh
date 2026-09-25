#!/usr/bin/env bash
# Remove the retired shipped YouTube Music web-app plugin without touching
# user-created plugins that merely happen to use the same directory name.

MIGRATION_ID="054-retire-ytmusic-web-plugin"
MIGRATION_TITLE="Retire shipped YouTube Music web plugin"
MIGRATION_DESCRIPTION="Removes the exact legacy default YouTube Music plugin copied by older Hadalis releases."
MIGRATION_TARGET_FILE="~/.config/inir/plugins/music/manifest.json"
MIGRATION_REQUIRED=true

_ytmusic_plugin_dir() {
  local base="${XDG_CONFIG_HOME:-$HOME/.config}"
  if [[ -L "$base/illogical-impulse" && -d "$base/inir" ]]; then
    printf '%s/plugins/music\n' "$base/inir"
  elif [[ -d "$base/illogical-impulse" ]]; then
    printf '%s/plugins/music\n' "$base/illogical-impulse"
  else
    printf '%s/plugins/music\n' "$base/inir"
  fi
}

_is_shipped_ytmusic_plugin() {
  local manifest="$1"
  [[ -f "$manifest" ]] || return 1
  jq -e '
    .id == "music"
    and .name == "YouTube Music"
    and .url == "https://music.youtube.com"
    and (.display // "tab") == "tab"
    and (.version // "1.0") == "1.0"
  ' "$manifest" >/dev/null 2>&1
}

migration_check() {
  local dir manifest
  dir="$(_ytmusic_plugin_dir)"
  manifest="$dir/manifest.json"
  _is_shipped_ytmusic_plugin "$manifest"
}

migration_preview() {
  echo "Remove the exact retired default plugin at: $(_ytmusic_plugin_dir)"
  echo "Custom plugins are left untouched unless their manifest exactly matches the shipped YouTube Music plugin."
}

migration_diff() {
  local dir manifest
  dir="$(_ytmusic_plugin_dir)"
  manifest="$dir/manifest.json"
  if _is_shipped_ytmusic_plugin "$manifest"; then
    jq '{id, name, url, display, version}' "$manifest"
  else
    echo "No shipped YouTube Music plugin detected."
  fi
}

migration_apply() {
  local dir manifest
  dir="$(_ytmusic_plugin_dir)"
  manifest="$dir/manifest.json"
  _is_shipped_ytmusic_plugin "$manifest" || return 0
  rm -rf -- "$dir"
  echo "Removed retired shipped YouTube Music web plugin"
}
