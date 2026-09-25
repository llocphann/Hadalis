#!/usr/bin/env bash
MIGRATION_ID="052-lock-provider"
MIGRATION_TITLE="Preserve external lock provider"
MIGRATION_DESCRIPTION="Migrates the retired lock.useHyprlock boolean to the compositor-neutral lock.provider setting."
MIGRATION_TARGET_FILE="~/.config/inir/config.json"
MIGRATION_REQUIRED=true

_lock_provider_config_path() {
  if declare -F resolve_inir_config_dir >/dev/null 2>&1; then
    printf '%s/config.json\n' "$(resolve_inir_config_dir)"
    return
  fi

  local xdg="${XDG_CONFIG_HOME:-$HOME/.config}"
  if [[ -f "$xdg/inir/config.json" ]]; then
    printf '%s\n' "$xdg/inir/config.json"
  elif [[ -f "$xdg/illogical-impulse/config.json" ]]; then
    printf '%s\n' "$xdg/illogical-impulse/config.json"
  else
    printf '%s\n' "$xdg/inir/config.json"
  fi
}

migration_check() {
  local conf
  conf="$(_lock_provider_config_path)"
  [[ -f "$conf" ]] || return 1
  jq -e '
    ((.lock? | type) == "object")
    and (.lock | has("useHyprlock"))
  ' "$conf" >/dev/null 2>&1
}

migration_preview() {
  local conf old
  conf="$(_lock_provider_config_path)"
  old="$(jq -r '.lock.useHyprlock // false' "$conf" 2>/dev/null || printf false)"
  if [[ "$old" == true ]]; then
    echo "Preserve external-lock preference as lock.provider = hyprlock"
  else
    echo "Normalize legacy lock preference to lock.provider = quickshell"
  fi
  echo "Remove retired lock.useHyprlock after conversion"
}

migration_apply() {
  local conf tmp
  conf="$(_lock_provider_config_path)"
  [[ -f "$conf" ]] || return 0

  tmp="$(mktemp "${conf}.migration-tmp.XXXXXX")" || return 1
  if ! jq '
    if ((.lock? | type) == "object") and (.lock | has("useHyprlock")) then
      .lock.provider = (
        if (.lock.provider? | type) == "string"
           and (.lock.provider == "quickshell"
                or .lock.provider == "swaylock"
                or .lock.provider == "hyprlock")
        then .lock.provider
        elif .lock.useHyprlock == true then "hyprlock"
        else "quickshell"
        end
      )
      | del(.lock.useHyprlock)
    else .
    end
  ' "$conf" > "$tmp"; then
    rm -f "$tmp"
    echo "  Failed to parse/update config; original file left unchanged." >&2
    return 1
  fi

  chmod --reference="$conf" "$tmp" 2>/dev/null || true
  mv "$tmp" "$conf"
}
