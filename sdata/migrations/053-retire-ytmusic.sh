#!/usr/bin/env bash
# Retire the built-in YTMusic backend after Local Music/MPD became canonical.

MIGRATION_ID="053-retire-ytmusic"
MIGRATION_TITLE="Retire built-in YTMusic"
MIGRATION_DESCRIPTION="Moves legacy YTMusic enable/order state to local Music, then removes the obsolete YTMusic config subtree."
MIGRATION_TARGET_FILE="~/.config/inir/config.json"
MIGRATION_REQUIRED=true

_ytmusic_config_path() {
  if declare -F resolve_inir_config_dir >/dev/null 2>&1; then
    printf '%s/config.json\n' "$(resolve_inir_config_dir)"
    return
  fi
  local base="${XDG_CONFIG_HOME:-$HOME/.config}"
  if [[ -f "$base/inir/config.json" ]]; then
    printf '%s\n' "$base/inir/config.json"
  elif [[ -f "$base/illogical-impulse/config.json" ]]; then
    printf '%s\n' "$base/illogical-impulse/config.json"
  else
    printf '%s\n' "$base/inir/config.json"
  fi
}

migration_check() {
  local conf
  conf="$(_ytmusic_config_path)"
  [[ -f "$conf" ]] || return 1
  jq -e '
    ((.sidebar?.ytmusic? | type) == "object")
    or (((.sidebar?.left?.tabOrder? // []) | index("ytmusic")) != null)
  ' "$conf" >/dev/null 2>&1
}

migration_preview() {
  echo "Move sidebar.ytmusic.enable=true to sidebar.music.enable=true"
  echo "Normalize sidebar.left.tabOrder: ytmusic -> music"
  echo "Remove sidebar.ytmusic"
}

migration_diff() {
  local conf
  conf="$(_ytmusic_config_path)"
  [[ -f "$conf" ]] || { echo "Config file not found."; return; }
  jq '{legacyEnabled: (.sidebar.ytmusic.enable // false), localMusicEnabled: (.sidebar.music.enable // false), tabOrder: (.sidebar.left.tabOrder // [])}' "$conf"
}

migration_apply() {
  local conf
  conf="$(_ytmusic_config_path)"
  [[ -f "$conf" ]] || return 0
  local tmp
  tmp="$(mktemp "${conf}.migration-tmp.XXXXXX")" || return 1
  if ! jq '
    if (.sidebar? | type) != "object" then .
    else
      .sidebar.music = (.sidebar.music // {})
      | if (.sidebar.ytmusic.enable // false) == true then .sidebar.music.enable = true else . end
      | if (.sidebar.left.tabOrder? | type) == "array"
          then .sidebar.left.tabOrder = (
            reduce .sidebar.left.tabOrder[] as $raw ([];
              ($raw | if . == "ytmusic" then "music" else . end) as $id
              | if index($id) == null then . + [$id] else . end
            )
          )
          else .
        end
      | del(.sidebar.ytmusic)
    end
  ' "$conf" > "$tmp"; then
    rm -f "$tmp"
    echo "Failed to migrate YTMusic config; original file left unchanged." >&2
    return 1
  fi
  chmod --reference="$conf" "$tmp" 2>/dev/null || true
  mv "$tmp" "$conf"
  echo "Retired built-in YTMusic config; Local Music/MPD remains canonical"
}
