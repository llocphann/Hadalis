#!/usr/bin/env bash
# SHA-pinned, synthetic-only MegaQML check; no vendor/account commands.
set -euo pipefail
umask 077
export LC_ALL=C
expected="${1:-}"
if [[ ! "$expected" =~ ^[0-9a-f]{40}$ ]]; then echo 'INVALID_SOURCE_SHA'; exit 64; fi
cd "$(git rev-parse --show-toplevel)"
[[ "$(git branch --show-current)" == dev ]] || { echo 'WRONG_BRANCH'; exit 65; }
source_sha="$(git rev-parse HEAD)"
[[ "$source_sha" == "$expected" ]] || { echo 'SOURCE_MISMATCH'; exit 66; }
[[ -z "$(git status --porcelain --untracked-files=all)" ]] || { echo 'DIRTY_WORKTREE'; exit 67; }
# Source is SHA-pinned. Intervening changes are allowed ONLY when every
# changed path is independently Wull-owned. Never rebase, reset or force-push.
wull_only_advance() {
  local older="$1" newer="$2" changed
  git merge-base --is-ancestor "$older" "$newer" || return 1
  while IFS= read -r -d '' changed; do
    case "$changed" in
      docs/wull-*|scripts/wull-*|scripts/test-wull-*|modules/abyss/*|to-do/cloud-bot/ABYSS_WATER_DROPLET_COMPANION.md) ;;
      *) return 1 ;;
    esac
  done < <(git diff --name-only -z "$older" "$newer" --)
}
fetch_remote_dev() {
  git fetch --quiet --no-tags origin refs/heads/dev || return 1
  remote_sha="$(git rev-parse FETCH_HEAD)"
}
fetch_remote_dev || { echo 'REMOTE_FETCH_FAILED'; exit 68; }
if [[ "$remote_sha" != "$expected" ]] && ! wull_only_advance "$expected" "$remote_sha"; then
  echo 'REMOTE_MISMATCH_UNREVIEWED'
  exit 68
fi
scratch="$(mktemp -d)"
trap 'rm -rf -- "$scratch"' EXIT
failed=0
qt_unqualified=0
run_test() {
  local name="$1" code state; shift
  if "$@" > "$scratch/$name.raw" 2>&1; then code=0; state=PASS
  else
    code=$?; state=FAIL
    case "$name" in
      # Parser/tool baselines can fail even with correct new source.
      # Never translate those into a false MegaQML source failure.
      qml_minimal|qml_modern_syntax|qml_baseline|qml_waffle_baseline|quickshell_baseline) qt_unqualified=1 ;;
      *) failed=1 ;;
    esac
  fi
  printf '%s,%s,%s,%s\n' "$name" "$state" "$code" "$source_sha" >> "$scratch/safe.csv"
}
run_test megaqml_phase2_contract python3 scripts/test-megaqml-phase2-contract.py
run_test settings_navigation python3 scripts/test-settings-information-architecture.py
run_test megaqml_waffle_navigation python3 scripts/test-megaqml-waffle-contract.py
run_test megaqml_static_protocol node scripts/test-megaqml-phase2-protocol.mjs
run_test megaqml_quickshell_diagnostics python3 scripts/test-megaqml-quickshell-classifier-contract.py
run_test megaqml_fake_dispatch_fixture python3 scripts/test-megaqml-fake-dispatch-contract.py
run_test megaqml_ui_component_fixture python3 scripts/test-megaqml-ui-fixture-contract.py
run_test megaqml_real_host_route_preflight python3 scripts/test-megaqml-host-route-contract.py
# Optional actual Quickshell singleton creation; zero consumers and isolated
# shell root. The fixture cannot resolve the production native-dispatch path.
if command -v qs >/dev/null 2>&1 || command -v quickshell >/dev/null 2>&1; then
  run_test quickshell_baseline bash scripts/test-megaqml-quickshell-smoke.sh baseline
  if grep -q '^quickshell_baseline,PASS,' "$scratch/safe.csv"; then
    run_test quickshell_service_dormant bash scripts/test-megaqml-quickshell-smoke.sh dormant
    if grep -q '^quickshell_service_dormant,PASS,' "$scratch/safe.csv"; then
      run_test quickshell_active_present bash scripts/test-megaqml-quickshell-smoke.sh active-present
      run_test quickshell_active_missing bash scripts/test-megaqml-quickshell-smoke.sh active-missing
      run_test quickshell_reject_wrong_id bash scripts/test-megaqml-quickshell-smoke.sh active-wrong-id
      run_test quickshell_reject_unsafe_secret bash scripts/test-megaqml-quickshell-smoke.sh active-unsafe-secret
      run_test quickshell_reject_malformed bash scripts/test-megaqml-quickshell-smoke.sh active-malformed
      run_test quickshell_exit_failure bash scripts/test-megaqml-quickshell-smoke.sh active-exit-failure
      run_test quickshell_deadline_reap bash scripts/test-megaqml-quickshell-smoke.sh active-hang
      run_test quickshell_refresh_coalesce bash scripts/test-megaqml-quickshell-smoke.sh refresh-coalesce
      run_test quickshell_refresh_stale_reacquire bash scripts/test-megaqml-quickshell-smoke.sh refresh-stale-reacquire
      run_test quickshell_recover_exit bash scripts/test-megaqml-quickshell-smoke.sh recovery-exit
      run_test quickshell_recover_timeout bash scripts/test-megaqml-quickshell-smoke.sh recovery-timeout
      run_test quickshell_ui_material bash scripts/test-megaqml-quickshell-smoke.sh ui-material
      run_test quickshell_ui_waffle bash scripts/test-megaqml-quickshell-smoke.sh ui-waffle
      run_test quickshell_ui_shared bash scripts/test-megaqml-quickshell-smoke.sh ui-shared
      run_test quickshell_ui_race bash scripts/test-megaqml-quickshell-smoke.sh ui-race
    else
      for case_name in quickshell_active_present quickshell_active_missing quickshell_reject_wrong_id quickshell_reject_unsafe_secret quickshell_reject_malformed quickshell_exit_failure quickshell_deadline_reap quickshell_refresh_coalesce quickshell_refresh_stale_reacquire quickshell_recover_exit quickshell_recover_timeout quickshell_ui_material quickshell_ui_waffle quickshell_ui_shared quickshell_ui_race; do
        printf '%s,SKIP,127,%s\n' "$case_name" "$source_sha" >> "$scratch/safe.csv"
      done
    fi
  else
    for case_name in quickshell_service_dormant quickshell_active_present quickshell_active_missing quickshell_reject_wrong_id quickshell_reject_unsafe_secret quickshell_reject_malformed quickshell_exit_failure quickshell_deadline_reap quickshell_refresh_coalesce quickshell_refresh_stale_reacquire quickshell_recover_exit quickshell_recover_timeout quickshell_ui_material quickshell_ui_waffle quickshell_ui_shared quickshell_ui_race; do
      printf '%s,SKIP,127,%s\n' "$case_name" "$source_sha" >> "$scratch/safe.csv"
    done
  fi
else
  for case_name in quickshell_baseline quickshell_service_dormant quickshell_active_present quickshell_active_missing quickshell_reject_wrong_id quickshell_reject_unsafe_secret quickshell_reject_malformed quickshell_exit_failure quickshell_deadline_reap quickshell_refresh_coalesce quickshell_refresh_stale_reacquire quickshell_recover_exit quickshell_recover_timeout quickshell_ui_material quickshell_ui_waffle quickshell_ui_shared quickshell_ui_race; do
    printf '%s,SKIP,127,%s\n' "$case_name" "$source_sha" >> "$scratch/safe.csv"
  done
fi
# Compile the reviewed local Rust source offline; never search an installed vendor.
if command -v cargo >/dev/null 2>&1; then
  run_test megaqml_rust_build cargo build --locked --offline --manifest-path native/Cargo.toml -p inir-mega
  if grep -q '^megaqml_rust_build,PASS,' "$scratch/safe.csv"; then
    run_test megaqml_fake_vendor_boundary node scripts/test-megaqml-phase2-rust-boundary.mjs native/target/debug/inir-mega
  else
    printf 'megaqml_fake_vendor_boundary,SKIP,127,%s\n' "$source_sha" >> "$scratch/safe.csv"
  fi
else
  printf 'megaqml_rust_build,SKIP,127,%s\n' "$source_sha" >> "$scratch/safe.csv"
  printf 'megaqml_fake_vendor_boundary,SKIP,127,%s\n' "$source_sha" >> "$scratch/safe.csv"
fi
# Optional Qt parser smoke: no QML runtime, account, mutation or output publication.
# qmlformat writes to stdout by default; never pass -i/-F.
# Only compare new QML after qmlformat parses both trivial Qt and existing repo QML.
# Otherwise newer files are UNQUALIFIED, not mislabeled as broken.
# Prefer an available Qt formatter that actually parses the modern Hadalis
# dialect. Some systems keep a legacy qmlformat first in PATH while Qt 6 is
# installed in a separate executable location. No tool is run on the shell UI.
printf 'import QtQuick\nItem {}\n' > "$scratch/qt-minimal.qml"
printf 'pragma ComponentBehavior: Bound\nimport QtQuick\nItem { function eligible(value: string): bool { return (value ?? "").length > 0 } }\n' > "$scratch/qt-modern.qml"
qt_formatter=""
qt_first=""
qt_formatter_selection="unavailable"
for candidate in /usr/lib/qt6/bin/qmlformat qmlformat6 qmlformat; do
  if ! command -v "$candidate" >/dev/null 2>&1; then continue; fi
  if [[ -z "$qt_first" ]]; then qt_first="$candidate"; fi
  if "$candidate" "$scratch/qt-minimal.qml" > "$scratch/qt-probe-minimal.raw" 2>&1 \
      && "$candidate" "$scratch/qt-modern.qml" > "$scratch/qt-probe-modern.raw" 2>&1; then
    qt_formatter="$candidate"
    qt_formatter_selection="modern_probe_pass"
    break
  fi
done
if [[ -z "$qt_formatter" && -n "$qt_first" ]]; then
  qt_formatter="$qt_first"
  qt_formatter_selection="fallback_probe_unqualified"
fi
qt_public_version="unknown"
if [[ -n "$qt_formatter" ]]; then
  version_line="$("$qt_formatter" -v 2>&1 || true)"
  version_line="${version_line:0:256}"
  if [[ "$version_line" =~ ([0-9]+)\.([0-9]+)(\.[0-9]+)? ]]; then
    qt_public_version="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}"
  fi
  run_test qml_minimal "$qt_formatter" "$scratch/qt-minimal.qml"
  run_test qml_modern_syntax "$qt_formatter" "$scratch/qt-modern.qml"
  if grep -q '^qml_minimal,PASS,' "$scratch/safe.csv"; then
    run_test qml_baseline "$qt_formatter" modules/settings/OverviewConfig.qml
    if grep -q '^qml_baseline,PASS,' "$scratch/safe.csv"; then
      run_test qml_service "$qt_formatter" services/deferred/CloudStorageService.qml
      run_test qml_page "$qt_formatter" modules/settings/CloudStorageConfig.qml
      # Independent Waffle Settings has its own QML baseline and standalone page.
      run_test qml_waffle_baseline "$qt_formatter" modules/waffle/settings/pages/WEffectsPage.qml
      if grep -q '^qml_waffle_baseline,PASS,' "$scratch/safe.csv"; then
        run_test qml_waffle_page "$qt_formatter" modules/waffle/settings/pages/WCloudStoragePage.qml
        run_test qml_waffle_entry "$qt_formatter" waffleSettings.qml
        run_test qml_waffle_content "$qt_formatter" modules/waffle/settings/WSettingsContent.qml
      else
        for case_name in qml_waffle_page qml_waffle_entry qml_waffle_content; do
          printf '%s,SKIP,127,%s\n' "$case_name" "$source_sha" >> "$scratch/safe.csv"
        done
      fi
    else
      printf 'qml_service,SKIP,127,%s\n' "$source_sha" >> "$scratch/safe.csv"
      printf 'qml_page,SKIP,127,%s\n' "$source_sha" >> "$scratch/safe.csv"
      printf 'qml_waffle_baseline,SKIP,127,%s\n' "$source_sha" >> "$scratch/safe.csv"
      for case_name in qml_waffle_page qml_waffle_entry qml_waffle_content; do
        printf '%s,SKIP,127,%s\n' "$case_name" "$source_sha" >> "$scratch/safe.csv"
      done
    fi
  else
    printf 'qml_baseline,SKIP,127,%s\n' "$source_sha" >> "$scratch/safe.csv"
    printf 'qml_service,SKIP,127,%s\n' "$source_sha" >> "$scratch/safe.csv"
    printf 'qml_page,SKIP,127,%s\n' "$source_sha" >> "$scratch/safe.csv"
    printf 'qml_waffle_baseline,SKIP,127,%s\n' "$source_sha" >> "$scratch/safe.csv"
    for case_name in qml_waffle_page qml_waffle_entry qml_waffle_content; do
      printf '%s,SKIP,127,%s\n' "$case_name" "$source_sha" >> "$scratch/safe.csv"
    done
  fi
else
  for case_name in qml_minimal qml_modern_syntax qml_baseline qml_service qml_page qml_waffle_baseline qml_waffle_page qml_waffle_entry qml_waffle_content; do
    printf '%s,SKIP,127,%s\n' "$case_name" "$source_sha" >> "$scratch/safe.csv"
  done
fi
report="docs/evidence/megaqml/phase2n-${source_sha:0:12}-$(date -u +%Y%m%dT%H%M%SZ).md"
mkdir -p docs/evidence/megaqml
{
  printf '# MegaQML Phase 2n real Settings host route preflight evidence\n\nSource SHA: `%s`\n\n' "$source_sha"
  printf 'Scope: Full Phase 2m synthetic 35-case regression, plus read-only source preflight of real Material/ii, Abyss overlay and SettingsFocus host routes and the independent Waffle Settings Loader. The new host preflight does not execute the full Hadalis UI or prove real widget rendering; all Quickshell runtime tests retain inert visual stubs. No full Hadalis render, installed vendor execution or account operations.\n\n'
  printf 'qt_formatter_selection=%s;version_major_minor=%s\n\n' "$qt_formatter_selection" "$qt_public_version"
  printf '| Test | Result | Exit code | Source SHA |\n|---|---|---:|---|\n'
  while IFS=, read -r name state code sha; do
    printf '| %s | %s | %s | %s |\n' "$name" "$state" "$code" "$sha"
  done < "$scratch/safe.csv"
  for qt_case in qml_baseline qml_service qml_page qml_waffle_baseline qml_waffle_page qml_waffle_entry qml_waffle_content; do
    if grep -q "^${qt_case},FAIL," "$scratch/safe.csv"; then
      python3 scripts/test-megaqml-qt-diagnostic.py "$qt_case" "$scratch/$qt_case.raw"
    fi
  done
  if grep -q '^qml_modern_syntax,FAIL,' "$scratch/safe.csv"; then
    echo 'qml_tool_feature_probe=modern_syntax_not_parsed'
  fi
  if grep -q '^qml_minimal,FAIL,' "$scratch/safe.csv"; then
    echo 'qml_blocker=tool_cannot_parse_minimal_qt'
  elif grep -q '^qml_baseline,FAIL,' "$scratch/safe.csv"; then
    echo 'qml_blocker=tool_cannot_parse_existing_repository_page'
  elif grep -q '^qml_waffle_baseline,FAIL,' "$scratch/safe.csv"; then
    echo 'qml_waffle_blocker=tool_cannot_parse_existing_waffle_page'
  elif grep -q '^qml_minimal,SKIP,' "$scratch/safe.csv"; then
    echo 'qml_blocker=qmlformat_unavailable'
  fi
  for qs_case in quickshell_baseline quickshell_service_dormant quickshell_active_present quickshell_active_missing quickshell_reject_wrong_id quickshell_reject_unsafe_secret quickshell_reject_malformed quickshell_exit_failure quickshell_deadline_reap quickshell_refresh_coalesce quickshell_refresh_stale_reacquire quickshell_recover_exit quickshell_recover_timeout quickshell_ui_material quickshell_ui_waffle quickshell_ui_shared quickshell_ui_race; do
    if grep -q "^${qs_case},FAIL," "$scratch/safe.csv"; then
      # The local smoke helper prints only allowlisted diagnostics.
      grep '^quickshell_smoke_category=' "$scratch/$qs_case.raw" || true
    fi
  done
  if grep -q '^quickshell_baseline,FAIL,' "$scratch/safe.csv"; then
    echo 'quickshell_runtime_blocker=baseline_environment_or_tool_failure'
  elif grep -q '^quickshell_baseline,SKIP,' "$scratch/safe.csv"; then
    echo 'quickshell_runtime_blocker=quickshell_not_available'
  fi
  if [[ "$failed" != 0 ]]; then
    echo 'Aggregate: FAIL (one or more executed required/new-source tests).'
  elif [[ "$qt_unqualified" != 0 ]]; then
    echo 'Aggregate: PASS (executed required tests); optional Qt/Quickshell baseline or environment UNQUALIFIED.'
  elif grep -q ',SKIP,' "$scratch/safe.csv"; then
    echo 'Aggregate: PASS (executed tests); some tests SKIPPED/UNQUALIFIED.'
  else
    echo 'Aggregate: PASS (synthetic and isolated Quickshell checks; no rendered Settings UI or live vendor).'
  fi
} > "$report"
cat "$scratch/safe.csv"
printf 'SOURCE_SHA=%s\nSAFE_REPORT=%s\n' "$source_sha" "$report"
if [[ "$(git status --porcelain --untracked-files=all)" != "?? $report" ]]; then
  echo 'PUBLICATION_SKIPPED_DIRTY_WORKTREE'; exit "$failed"
fi
# Keep report's SOURCE_SHA unchanged, even if Wull commits arrive before
# publication. Fast-forward only the reviewed Wull-only remote ancestry.
fetch_remote_dev || { echo 'PUBLICATION_SKIPPED_REMOTE_FETCH'; exit 69; }
if [[ "$remote_sha" != "$(git rev-parse HEAD)" ]]; then
  if ! wull_only_advance "$source_sha" "$remote_sha"; then
    echo 'PUBLICATION_SKIPPED_REMOTE_MOVED_UNREVIEWED'
    exit 69
  fi
  if ! git merge --ff-only FETCH_HEAD >/dev/null; then
    echo 'PUBLICATION_SKIPPED_REMOTE_NOT_FAST_FORWARD'
    exit 69
  fi
fi
if [[ "$(git status --porcelain --untracked-files=all)" != "?? $report" ]]; then
  echo 'PUBLICATION_SKIPPED_DIRTY_AFTER_MERGE'
  exit 69
fi
if [[ -z "$(git config user.name || true)" || -z "$(git config user.email || true)" ]]; then
  echo 'PUBLICATION_SKIPPED_GIT_IDENTITY'; exit "$failed"
fi
git add -- "$report"
if [[ "$(git diff --cached --name-only)" != "$report" ]] || ! git diff --cached --check; then
  git reset --quiet -- "$report"
  echo 'PUBLICATION_SKIPPED_INDEX'; exit "$failed"
fi
if ! git commit --quiet -m "test(megaqml): Phase 2n real Settings host route preflight smoke evidence ${source_sha:0:12}" -- "$report"; then
  echo 'PUBLICATION_SKIPPED_COMMIT'; exit "$failed"
fi
evidence_sha="$(git rev-parse HEAD)"
if git push --quiet origin HEAD:refs/heads/dev; then
  printf 'PUBLICATION=PUSHED_SAFE_SUMMARY\nEVIDENCE_COMMIT=%s\n' "$evidence_sha"
else
  printf 'PUBLICATION=LOCAL_ONLY\nLOCAL_EVIDENCE_COMMIT=%s\n' "$evidence_sha"
fi
exit "$failed"
