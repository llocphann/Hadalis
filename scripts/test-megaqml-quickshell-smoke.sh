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
# Always run under a fresh isolated Quickshell configuration root, not the
# repository. Copy only reviewed files; the root intentionally contains no
# scripts/native-dispatch. Never run an installed vendor program.
fixture_dir="$work/fixture"
mkdir -p "$fixture_dir/services"
cp -- "scripts/megaqml-fixtures/runtime-$kind/shell.qml" "$fixture_dir/shell.qml"
if [[ "$kind" == dormant ]]; then
  cp -- services/deferred/CloudStorageService.qml "$fixture_dir/services/CloudStorageService.qml"
  cp -- services/deferred/CloudStorageStaticProtocol.js "$fixture_dir/services/CloudStorageStaticProtocol.js"
  printf 'singleton CloudStorageService 1.0 CloudStorageService.qml\n' > "$fixture_dir/services/qmldir"
fi
test ! -e "$fixture_dir/scripts/native-dispatch" || exit 75
if timeout --kill-after=2s 12s "$qs_bin" --path "$fixture_dir/shell.qml" >"$work/stdout" 2>"$work/stderr"; then
  case "$kind" in
    baseline) marker=MEGAQML_QS_BASELINE_OK ;;
    dormant) marker=MEGAQML_QS_DORMANT_OK ;;
  esac
  if grep -Fq "$marker" "$work/stdout" "$work/stderr"; then
    echo "PASS isolated Quickshell $kind smoke"
    exit 0
  fi
  python3 scripts/test-megaqml-quickshell-classify.py "$work/stdout" "$work/stderr" "$kind"
  echo "QUICKSHELL_SENTINEL_ABSENT"
  exit 88
fi
python3 scripts/test-megaqml-quickshell-classify.py "$work/stdout" "$work/stderr" "$kind"
echo "QUICKSHELL_SMOKE_UNAVAILABLE_OR_FAILED"
exit 89
