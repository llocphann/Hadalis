#!/usr/bin/env bash
# Manual one-shot, no vendor calls, no background service, no user config access.
set -euo pipefail
umask 077
case "${1:-}" in baseline|dormant) kind="$1" ;; *) exit 64 ;; esac
cd "$(git rev-parse --show-toplevel)"
qs_bin=""
if command -v qs >/dev/null 2>&1; then qs_bin="$(command -v qs)"
elif command -v quickshell >/dev/null 2>&1; then qs_bin="$(command -v quickshell)"
else exit 77
fi
work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/config" "$work/data" "$work/cache" "$work/state" "$work/no-native-binaries"
export XDG_CONFIG_HOME="$work/config"
export XDG_DATA_HOME="$work/data"
export XDG_CACHE_HOME="$work/cache"
export XDG_STATE_HOME="$work/state"
export INIR_NATIVE_BIN_DIR="$work/no-native-binaries"
export QT_QPA_PLATFORM=offscreen
export QS_NO_RELOAD_POPUP=1
fixture="scripts/megaqml-fixtures/runtime-$kind/shell.qml"
if timeout --kill-after=2s 12s "$qs_bin" --path "$fixture" >"$work/stdout" 2>"$work/stderr"; then
  case "$kind" in
    baseline) marker=MEGAQML_QS_BASELINE_OK ;;
    dormant) marker=MEGAQML_QS_DORMANT_OK ;;
  esac
  if grep -Fq "$marker" "$work/stdout" "$work/stderr"; then
    echo "PASS isolated Quickshell $kind smoke"
    exit 0
  fi
  echo "QUICKSHELL_SENTINEL_ABSENT"
  exit 88
fi
echo "QUICKSHELL_SMOKE_UNAVAILABLE_OR_FAILED"
exit 89
