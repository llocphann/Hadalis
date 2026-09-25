#!/usr/bin/env bash
set -uo pipefail

runtime_candidates=()
[[ -n "${INIR_RUNTIME_ROOT:-}" ]] && runtime_candidates+=("$INIR_RUNTIME_ROOT")
[[ -n "${XDG_CONFIG_HOME:-}" ]] && runtime_candidates+=("$XDG_CONFIG_HOME/quickshell/inir")
runtime_candidates+=(
    "$HOME/.config/quickshell/inir"
    "/usr/local/share/quickshell/inir"
    "/usr/share/quickshell/inir"
)

for runtime_root in "${runtime_candidates[@]}"; do
    dispatch="$runtime_root/scripts/native-dispatch"
    if [[ -x "$dispatch" ]]; then
        exec "$dispatch" super-tap "$@"
    fi
done

fallback="${INIR_SUPER_PYTHON_FALLBACK:-$HOME/.local/bin/inir_super_overview_daemon.py}"
if [[ -f "$fallback" ]]; then
    exec /usr/bin/env python3 "$fallback" "$@"
fi

echo "[inir-super] native selector and Python fallback are unavailable" >&2
exit 127
