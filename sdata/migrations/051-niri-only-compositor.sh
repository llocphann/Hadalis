#!/usr/bin/env bash
MIGRATION_ID="051-niri-only-compositor"
MIGRATION_TITLE="Retire legacy compositor service wiring"
MIGRATION_DESCRIPTION="Removes obsolete non-Niri inir.service wants wiring after the Niri-only cutover."
MIGRATION_TARGET_FILE=""
MIGRATION_REQUIRED=true

legacy_wants_dir() {
    printf '%s/systemd/user/%s' "${XDG_CONFIG_HOME:-$HOME/.config}" 'wayland-wm@Hyprland.service.wants'
}

migration_check() {
    [[ -L "$(legacy_wants_dir)/inir.service" || -e "$(legacy_wants_dir)/inir.service" ]]
}

migration_preview() {
    echo "Remove obsolete compositor wants link; Niri service wiring remains authoritative"
}

migration_apply() {
    local wants_dir
    wants_dir="$(legacy_wants_dir)"
    rm -f "$wants_dir/inir.service"
    rmdir "$wants_dir" 2>/dev/null || true
    command -v systemctl >/dev/null 2>&1         && systemctl --user daemon-reload >/dev/null 2>&1 || true
}
