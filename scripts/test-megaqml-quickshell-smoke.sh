#!/usr/bin/env bash
# Manual one-shot, no vendor calls, no background service, no user config access.
set -euo pipefail
umask 077
case "${1:-}" in baseline|dormant|active-present|active-missing|active-wrong-id|active-unsafe-secret|active-malformed|active-exit-failure|active-hang|refresh-coalesce|refresh-stale-reacquire|recovery-exit|recovery-timeout|ui-material|ui-waffle|ui-shared|ui-preflight-timeout|ui-preflight-release|ui-race|ui-host) kind="$1" ;; *) exit 64 ;; esac
cd "$(git rev-parse --show-toplevel)"
qs_bin=""
if command -v qs >/dev/null 2>&1; then qs_bin="$(command -v qs)"
elif command -v quickshell >/dev/null 2>&1; then qs_bin="$(command -v quickshell)"
else exit 77
fi
work="$(mktemp -d)"
safe_rm="$(command -v rm)"
trap '"$safe_rm" -rf -- "$work"' EXIT
mkdir -p "$work/config" "$work/data" "$work/cache" "$work/state" "$work/no-native-binaries"
export XDG_CONFIG_HOME="$work/config"
export XDG_DATA_HOME="$work/data"
export XDG_CACHE_HOME="$work/cache"
export XDG_STATE_HOME="$work/state"
export INIR_NATIVE_BIN_DIR="$work/no-native-binaries"
export QT_QPA_PLATFORM=offscreen
export QS_NO_RELOAD_POPUP=1
safe_grep="$(command -v grep)"
safe_python="$(command -v python3)"
safe_timeout="$(command -v timeout)"
# Always run under a fresh isolated Quickshell configuration root, not the
# repository. Copy only reviewed files. Active modes install a Python-only
# fake dispatcher inside the temporary fixture; never run vendor software.
fixture_dir="$work/fixture"
mkdir -p "$fixture_dir/services"
# Both active scenarios intentionally share one fixture; variant arrives
# only via the synthetic MEGAQML_FIXTURE_CASE environment variable.
fixture_kind="${kind%%-*}"
source_fixture="scripts/megaqml-fixtures/runtime-$fixture_kind/shell.qml"
if [[ "$kind" == ui-shared || "$kind" == ui-race || "$kind" == ui-host ]]; then
  source_fixture="scripts/megaqml-fixtures/runtime-$kind/shell.qml"
elif [[ "$kind" == ui-preflight-timeout || "$kind" == ui-preflight-release ]]; then
  source_fixture="scripts/megaqml-fixtures/runtime-ui-shared/shell.qml"
fi
if [[ ! -f "$source_fixture" ]]; then
  echo 'FIXTURE_SOURCE_MISSING'
  exit 76
fi
cp -- "$source_fixture" "$fixture_dir/shell.qml"
if [[ "$kind" == ui-race ]]; then
  cp -- scripts/megaqml-fixtures/runtime-ui-race/RaceStageGuard.js "$fixture_dir/RaceStageGuard.js"
fi
if [[ "$kind" == ui-* ]]; then
  # Only real Cloud Storage page and service files are copied; all unrelated
  # visual dependencies are synthetic stubs. No production dispatcher.
  fixture_ui_kind="${kind#ui-}"
  if [[ "$fixture_ui_kind" == race || "$fixture_ui_kind" == preflight-timeout || "$fixture_ui_kind" == preflight-release ]]; then fixture_ui_kind=shared; fi
  if [[ "$kind" == ui-host ]]; then
    "$safe_python" scripts/test-megaqml-host-ui-fixture.py "$fixture_dir" >/dev/null
  else
    "$safe_python" scripts/test-megaqml-ui-fixture.py "$fixture_ui_kind" "$fixture_dir" >/dev/null
  fi
fi
if [[ "$kind" == dormant || "$kind" == active-* || "$kind" == refresh-* || "$kind" == recovery-* ]]; then
  cp -- services/deferred/CloudStorageService.qml "$fixture_dir/services/CloudStorageService.qml"
  cp -- services/deferred/CloudStorageStaticProtocol.js "$fixture_dir/services/CloudStorageStaticProtocol.js"
  cp -- services/deferred/CloudStoragePreflightProtocol.js "$fixture_dir/services/CloudStoragePreflightProtocol.js"
  printf 'singleton CloudStorageService 1.0 CloudStorageService.qml\n' > "$fixture_dir/services/qmldir"
fi
test ! -e "$fixture_dir/scripts/native-dispatch" || exit 75
case "$kind" in
  active-present|active-missing|active-wrong-id|active-unsafe-secret|active-malformed|active-exit-failure|active-hang|refresh-coalesce|refresh-stale-reacquire|recovery-exit|recovery-timeout|ui-material|ui-waffle|ui-shared|ui-preflight-timeout|ui-preflight-release|ui-race|ui-host)
    mkdir -p "$fixture_dir/scripts" "$work/allowed-bin"
    cp -- scripts/megaqml-fixtures/fake-static-dispatch.py "$fixture_dir/scripts/native-dispatch"
    chmod 700 "$fixture_dir/scripts/native-dispatch"
    for tool in python3 bash sh; do
      ln -s -- "$(command -v "$tool")" "$work/allowed-bin/$tool"
    done
    if [[ "$kind" == ui-* ]]; then
      if [[ "$kind" == ui-race ]]; then
        export MEGAQML_FIXTURE_CASE=shared-race
      elif [[ "$kind" == ui-shared ]]; then
        export MEGAQML_FIXTURE_CASE=preflight-third-wrong-id
      elif [[ "$kind" == ui-preflight-timeout ]]; then
        export MEGAQML_FIXTURE_CASE=preflight-timeout
        export MEGAQML_PREFLIGHT_TIMEOUT=1
      elif [[ "$kind" == ui-preflight-release ]]; then
        export MEGAQML_FIXTURE_CASE=preflight-timeout
        export MEGAQML_PREFLIGHT_RELEASE=1
      else
        export MEGAQML_FIXTURE_CASE=missing
      fi
      export MEGAQML_UI_KIND="${kind#ui-}"
    elif [[ "$kind" == recovery-* ]]; then
      export MEGAQML_FIXTURE_CASE="retry-${kind#recovery-}"
    else
      export MEGAQML_FIXTURE_CASE="${kind#*-}"
    fi
    # The child cannot discover installed MEGAcmd clients through PATH.
    export PATH="$work/allowed-bin"
    ;;
esac
if "$safe_timeout" --kill-after=2s 12s "$qs_bin" --path "$fixture_dir/shell.qml" >"$work/stdout" 2>"$work/stderr"; then
  case "$kind" in
    baseline) marker=MEGAQML_QS_BASELINE_OK ;;
    dormant) marker=MEGAQML_QS_DORMANT_OK ;;
    active-present) marker=MEGAQML_QS_ACTIVE_PRESENT_OK ;;
    active-missing) marker=MEGAQML_QS_ACTIVE_MISSING_OK ;;
    active-wrong-id|active-unsafe-secret|active-malformed) marker=MEGAQML_QS_REJECTED_OK ;;
    active-exit-failure) marker=MEGAQML_QS_EXIT_FAILURE_OK ;;
    active-hang) marker=MEGAQML_QS_TIMEOUT_OK ;;
    refresh-coalesce) marker=MEGAQML_QS_COALESCED_OK ;;
    refresh-stale-reacquire) marker=MEGAQML_QS_REACQUIRE_OK ;;
    recovery-exit) marker=MEGAQML_QS_EXIT_RECOVERY_OK ;;
    recovery-timeout) marker=MEGAQML_QS_TIMEOUT_RECOVERY_OK ;;
    ui-material) marker=MEGAQML_QS_UI_MATERIAL_OK ;;
    ui-waffle) marker=MEGAQML_QS_UI_WAFFLE_OK ;;
    ui-shared) marker=MEGAQML_QS_UI_SHARED_OK ;;
    ui-preflight-timeout) marker=MEGAQML_QS_UI_SHARED_TIMEOUT_OK ;;
    ui-preflight-release) marker=MEGAQML_QS_UI_SHARED_RELEASE_OK ;;
    ui-race) marker=MEGAQML_QS_UI_RACE_OK ;;
    ui-host) marker=MEGAQML_QS_UI_HOST_OK ;;
  esac
  if "$safe_grep" -Fq "$marker" "$work/stdout" "$work/stderr"; then
    echo "PASS isolated Quickshell $kind smoke"
    exit 0
  fi
  "$safe_python" scripts/test-megaqml-quickshell-classify.py "$work/stdout" "$work/stderr" "$kind"
  echo "QUICKSHELL_SENTINEL_ABSENT"
  exit 88
fi
"$safe_python" scripts/test-megaqml-quickshell-classify.py "$work/stdout" "$work/stderr" "$kind"
echo "QUICKSHELL_SMOKE_UNAVAILABLE_OR_FAILED"
exit 89
