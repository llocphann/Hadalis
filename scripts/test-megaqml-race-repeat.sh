#!/usr/bin/env bash
# Eight fresh synthetic-only Quickshell sessions; no child diagnostics published.
set -euo pipefail
umask 077
export LC_ALL=C
cd "$(git rev-parse --show-toplevel)"
repetitions=8
passed=0
printf 'race_repeat_attempts=%d\n' "$repetitions"
for ((attempt=1; attempt<=repetitions; attempt++)); do
  code=0
  output="$(bash scripts/test-megaqml-quickshell-smoke.sh ui-race 2>&1)" || code=$?
  if [[ "$code" == 0 ]] && grep -Fqx 'PASS isolated Quickshell ui-race smoke' <<< "$output"; then
    passed=$((passed + 1))
    continue
  fi
  category=unclassified_failure
  while IFS= read -r line; do
    if [[ "$line" =~ ^quickshell_smoke_category=ui-race:([a-z_]+)$ ]]; then
      case "${BASH_REMATCH[1]}" in
        race_preflight|race_load|race_create|race_first_start|race_hide_one|race_queue|race_first_pending|race_second_start|race_last_release|race_reacquire|race_stale_reply|race_stale_installed|race_stale_lease|race_stale_unavailable|race_stale_snapshot|race_third_start|race_third_result|race_final_release|race_timeout|unexpected_race_state|missing_import|qml_type_resolution|qml_reference_or_type_error|qml_syntax|environment_permission|headless_platform|sentinel_seen_nonzero_exit|no_diagnostic_output|unclassified)
          category="${BASH_REMATCH[1]}" ;;
      esac
      break
    fi
  done <<< "$output"
  printf 'race_repeat_passes=%d\n' "$passed"
  printf 'race_repeat_first_failure=%d\n' "$attempt"
  printf 'race_repeat_failure_category=%s\n' "$category"
  exit 88
done
printf 'race_repeat_passes=%d\n' "$passed"
printf 'PASS MegaQML isolated race repeatability %d/%d\n' "$passed" "$repetitions"
