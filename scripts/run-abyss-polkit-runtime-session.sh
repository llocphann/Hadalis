#!/usr/bin/env bash
# Session-side launcher for the disposable real-Polkit CI user.
set -euo pipefail

: "${HADALIS_POLKIT_CI_TOKEN:?missing CI auth token}"
: "${HADALIS_POLKIT_CI_REPO:?missing repo path}"
: "${HADALIS_POLKIT_CI_STATUS_FILE:?missing status file}"
: "${HADALIS_POLKIT_CI_WESTON_LOG:?missing Weston log path}"
: "${HADALIS_POLKIT_CI_TOOL_PATH:?missing Nix runtime tool path}"

# PAM/systemd service activation intentionally starts with a conservative PATH.
# Re-add only the Nix runtime tool directories resolved by the parent nix shell,
# then normal system bins for pkcheck/bash and session utilities.
export PATH="$HADALIS_POLKIT_CI_TOOL_PATH:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export WAYLAND_DISPLAY=wayland-hadalis-polkit
export QT_QPA_PLATFORM=wayland
export QT_QUICK_BACKEND=software
export QSG_RENDER_LOOP=basic
export LIBGL_ALWAYS_SOFTWARE=1

weston_pid=""
cleanup() {
    if [[ -n "$weston_pid" ]]; then
        kill "$weston_pid" 2>/dev/null || true
        wait "$weston_pid" 2>/dev/null || true
    fi
    if [[ ! -f "$HADALIS_POLKIT_CI_STATUS_FILE" ]]; then
        printf 'FAIL\n' > "$HADALIS_POLKIT_CI_STATUS_FILE"
    fi
}
trap cleanup EXIT

weston \
    --backend=headless-backend.so \
    --socket="$WAYLAND_DISPLAY" \
    --idle-time=0 \
    --log="$HADALIS_POLKIT_CI_WESTON_LOG" &
weston_pid=$!

for _ in $(seq 1 100); do
    [[ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]] && break
    if ! kill -0 "$weston_pid" 2>/dev/null; then
        cat "$HADALIS_POLKIT_CI_WESTON_LOG" || true
        exit 1
    fi
    sleep 0.1
done

if [[ ! -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]]; then
    cat "$HADALIS_POLKIT_CI_WESTON_LOG" || true
    printf 'Weston headless socket did not become ready\n' >&2
    exit 1
fi

cd "$HADALIS_POLKIT_CI_REPO"
if bash scripts/test-abyss-polkit-runtime.sh; then
    printf 'PASS\n' > "$HADALIS_POLKIT_CI_STATUS_FILE"
else
    printf 'FAIL\n' > "$HADALIS_POLKIT_CI_STATUS_FILE"
    exit 1
fi
