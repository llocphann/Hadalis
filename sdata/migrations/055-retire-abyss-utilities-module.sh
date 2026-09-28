#!/usr/bin/env bash
# Utilities is a connected popup launched from the Quick Actions module. Remove
# the short-lived standalone Screen Edge placement while preserving the popup
# position settings and every unrelated module.

MIGRATION_ID="055-retire-abyss-utilities-module"
MIGRATION_TITLE="Move Abyss Utilities into Quick Actions"
MIGRATION_DESCRIPTION="Removes persisted standalone Utilities Screen Edge modules; Utilities remains available from the Quick Actions icon."
MIGRATION_REQUIRED=true

_abyss_utilities_config_path() {
  local root="${XDG_CONFIG_HOME:-$HOME/.config}"
  if [[ -f "$root/illogical-impulse/config.json" ]]; then
    printf '%s' "$root/illogical-impulse/config.json"
  else
    printf '%s' "$root/inir/config.json"
  fi
}

MIGRATION_TARGET_FILE="$(_abyss_utilities_config_path)"

migration_check() {
  local conf
  conf="$(_abyss_utilities_config_path)"
  [[ -f "$conf" ]] || return 1
  jq -e '
    [
      (.abyss.modules.placements[]?.kind),
      (.abyss.modules.outputLayouts[]?.placements[]?.kind)
    ] | any(. == "utilities")
  ' "$conf" >/dev/null 2>&1
}

migration_preview() {
  echo -e "${STY_RED:-}- standalone Abyss Utilities Edge module${STY_RST:-}"
  echo -e "${STY_GREEN:-}+ Utilities icon inside Quick Actions${STY_RST:-}"
}

migration_apply() {
  local conf tmp
  conf="$(_abyss_utilities_config_path)"
  [[ -f "$conf" ]] || return 0
  tmp="${conf}.migration-tmp"
  jq '
    if .abyss?.modules then
      .abyss.modules.placements = ((.abyss.modules.placements // [])
        | map(select(.kind != "utilities")))
      | .abyss.modules.outputLayouts = ((.abyss.modules.outputLayouts // [])
        | map(.placements = ((.placements // [])
          | map(select(.kind != "utilities")))))
    else . end
  ' "$conf" > "$tmp" && mv "$tmp" "$conf"
}
