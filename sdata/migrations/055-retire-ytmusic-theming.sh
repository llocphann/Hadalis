#!/usr/bin/env bash
# Retire the YouTube Music/Pear Desktop theming integration while preserving unrelated user state.
MIGRATION_ID="055-retire-ytmusic-theming"
MIGRATION_TITLE="Retire YouTube Music theming integration"
MIGRATION_DESCRIPTION="Removes Hadalis-owned Pear/YouTube Music theme state, config, and CDP launch flags."
MIGRATION_TARGET_FILE="~/.config/inir/config.json"
MIGRATION_REQUIRED=true

_ytmusic_shell_config_path() {
  local base="${XDG_CONFIG_HOME:-$HOME/.config}"
  if [[ -L "$base/illogical-impulse" && -d "$base/inir" ]]; then printf '%s/config.json\n' "$base/inir"
  elif [[ -f "$base/illogical-impulse/config.json" ]]; then printf '%s/config.json\n' "$base/illogical-impulse"
  else printf '%s/config.json\n' "$base/inir"; fi
}
_ytmusic_app_config_path() { printf '%s/YouTube Music/config.json\n' "${XDG_CONFIG_HOME:-$HOME/.config}"; }
_ytmusic_generated_css_path() { printf '%s/quickshell/user/generated/pear-desktop-theme.css\n' "${XDG_STATE_HOME:-$HOME/.local/state}"; }
_ytmusic_desktop_override_has_cdp() {
  local app file
  for app in pear-desktop youtube-music; do
    file="$HOME/.local/share/applications/$app.desktop"
    [[ -f "$file" ]] && grep -Fq -- '--remote-debugging-port=9223' "$file" && return 0
  done
  return 1
}
migration_check() {
  local shell_conf="$(_ytmusic_shell_config_path)" app_conf="$(_ytmusic_app_config_path)" css="$(_ytmusic_generated_css_path)"
  [[ -f "$shell_conf" ]] && jq -e '.appearance?.wallpaperTheming? | has("enablePearDesktop")' "$shell_conf" >/dev/null 2>&1 && return 0
  [[ -f "$app_conf" ]] && jq -e '(.options?.themes? | type) == "array" and any(.options.themes[]; type == "string" and endswith("/pear-desktop-theme.css"))' "$app_conf" >/dev/null 2>&1 && return 0
  [[ -f "$css" ]] && return 0
  _ytmusic_desktop_override_has_cdp
}
migration_preview() {
  echo "Remove the retired Hadalis YouTube Music/Pear Desktop theme config, generated CSS, and CDP launch flag"
}
migration_diff() {
  local shell_conf="$(_ytmusic_shell_config_path)" app_conf="$(_ytmusic_app_config_path)"
  [[ -f "$shell_conf" ]] && jq '{enablePearDesktop: .appearance.wallpaperTheming.enablePearDesktop}' "$shell_conf" 2>/dev/null || true
  [[ -f "$app_conf" ]] && jq '{themes: (.options.themes // [])}' "$app_conf" 2>/dev/null || true
}
migration_apply() {
  local shell_conf="$(_ytmusic_shell_config_path)" app_conf="$(_ytmusic_app_config_path)" css="$(_ytmusic_generated_css_path)" tmp app file
  if [[ -f "$shell_conf" ]]; then
    tmp="$(mktemp "${shell_conf}.migration-tmp.XXXXXX")" || return 1
    jq 'del(.appearance.wallpaperTheming.enablePearDesktop)' "$shell_conf" > "$tmp" || { rm -f "$tmp"; return 1; }
    chmod --reference="$shell_conf" "$tmp" 2>/dev/null || true; mv "$tmp" "$shell_conf"
  fi
  if [[ -f "$app_conf" ]]; then
    tmp="$(mktemp "${app_conf}.migration-tmp.XXXXXX")" || return 1
    jq 'if (.options?.themes? | type) == "array" then .options.themes = [.options.themes[] | select((type == "string" and endswith("/pear-desktop-theme.css")) | not)] else . end' "$app_conf" > "$tmp" || { rm -f "$tmp"; return 1; }
    chmod --reference="$app_conf" "$tmp" 2>/dev/null || true; mv "$tmp" "$app_conf"
  fi
  rm -f -- "$css"
  for app in pear-desktop youtube-music; do
    file="$HOME/.local/share/applications/$app.desktop"
    [[ -f "$file" ]] && grep -Fq -- '--remote-debugging-port=9223' "$file" && sed -i 's/ --remote-debugging-port=9223//g' "$file"
  done
  echo "Retired YouTube Music/Pear Desktop theming integration"
}
