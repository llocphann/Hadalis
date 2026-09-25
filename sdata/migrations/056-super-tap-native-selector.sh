#!/usr/bin/env bash
# Migration 056: Route existing opt-in Super-tap services through native-dispatch.

MIGRATION_ID="056-super-tap-native-selector"
MIGRATION_TITLE="Route Super-tap daemon through the native backend selector"
MIGRATION_DESCRIPTION="Moves an existing opt-in Super-tap service to the Rust-first native selector while retaining the Python evdev daemon as fallback."
MIGRATION_TARGET_FILE="~/.config/systemd/user/inir-super-overview.service"
MIGRATION_REQUIRED=true

_super_config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
_super_runtime="${_super_config_home}/quickshell/inir"
_super_service_dst="${_super_config_home}/systemd/user/inir-super-overview.service"
_super_launcher_dst="${HOME}/.local/bin/inir_super_overview_launcher.sh"

migration_check() {
    [[ -f "$_super_service_dst" ]] || return 1
    grep -Fq 'inir_super_overview_daemon.py' "$_super_service_dst" 2>/dev/null
}

migration_preview() {
    echo "Route the existing opt-in Super-tap service through native-dispatch."
    echo "Rust becomes the preferred daemon; the installed Python daemon remains the automatic fallback."
}

migration_apply() {
    local launcher_src="${_super_runtime}/scripts/daemon/inir_super_overview_launcher.sh"
    local service_src="${_super_runtime}/scripts/systemd/inir-super-overview.service"

    [[ -f "$launcher_src" && -f "$service_src" ]] || return 1
    install -Dm755 "$launcher_src" "$_super_launcher_dst" || return 1
    install -Dm644 "$service_src" "$_super_service_dst" || return 1

    if command -v systemctl >/dev/null 2>&1; then
        systemctl --user daemon-reload >/dev/null 2>&1 || true
        if systemctl --user is-active --quiet inir-super-overview.service 2>/dev/null; then
            systemctl --user restart inir-super-overview.service >/dev/null 2>&1 || return 1
        fi
    fi
}
