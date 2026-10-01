#!/usr/bin/env bash
# Focused, SHA-pinned Phase 2k loader diagnostics: synthetic UI only.
# No full Hadalis session, installed MEGAcmd process, account or network test.
set -euo pipefail
umask 077
export LC_ALL=C
[[ "$#" == 1 ]] || { echo 'INVALID_SOURCE_SHA'; exit 64; }
expected="$1"
[[ "$expected" =~ ^[0-9a-f]{40}$ ]] || { echo 'INVALID_SOURCE_SHA'; exit 64; }
cd "$(git rev-parse --show-toplevel)"
[[ "$(git branch --show-current)" == dev ]] || { echo 'WRONG_BRANCH'; exit 65; }
source_sha="$(git rev-parse HEAD)"
[[ "$source_sha" == "$expected" ]] || { echo 'SOURCE_MISMATCH'; exit 66; }
[[ -z "$(git status --porcelain --untracked-files=all)" ]] || { echo 'DIRTY_WORKTREE'; exit 67; }
# Concurrent Wull commits must not invalidate unchanged MegaQML checks.
# Only explicit Wull paths are accepted; all other remote changes stop this run.
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
unqualified=0
run_check() {
  local name="$1" code state
  shift
  if "$@" > "$scratch/$name.raw" 2>&1; then
    code=0
    state=PASS
  else
    code=$?
    state=FAIL
    if [[ "$name" == quickshell_baseline ]]; then unqualified=1
    else failed=1; fi
  fi
  printf '%s,%s,%s,%s\n' "$name" "$state" "$code" "$source_sha" >> "$scratch/safe.csv"
}
skip_check() {
  printf '%s,SKIP,127,%s\n' "$1" "$source_sha" >> "$scratch/safe.csv"
}

run_check megaqml_phase2_contract python3 scripts/test-megaqml-phase2-contract.py
run_check megaqml_ui_fixture_contract python3 scripts/test-megaqml-ui-fixture-contract.py
run_check megaqml_diagnostic_redaction python3 scripts/test-megaqml-quickshell-classifier-contract.py

if command -v qs >/dev/null 2>&1 || command -v quickshell >/dev/null 2>&1; then
  run_check quickshell_baseline bash scripts/test-megaqml-quickshell-smoke.sh baseline
  if grep -q '^quickshell_baseline,PASS,' "$scratch/safe.csv" \
      && grep -q '^megaqml_ui_fixture_contract,PASS,' "$scratch/safe.csv" \
      && grep -q '^megaqml_phase2_contract,PASS,' "$scratch/safe.csv"; then
    # Safe smoke copies the actual reviewed Cloud Storage pages and service,
    # but replaces unrelated visual dependencies and the dispatcher with
    # confined local stubs and a Python-only static detector.
    run_check quickshell_ui_material bash scripts/test-megaqml-quickshell-smoke.sh ui-material
    run_check quickshell_ui_waffle bash scripts/test-megaqml-quickshell-smoke.sh ui-waffle
  else
    skip_check quickshell_ui_material
    skip_check quickshell_ui_waffle
    unqualified=1
  fi
else
  unqualified=1
  skip_check quickshell_baseline
  skip_check quickshell_ui_material
  skip_check quickshell_ui_waffle
fi

report="docs/evidence/megaqml/phase2k-loader-$(git rev-parse --short=12 HEAD)-$(date -u +%Y%m%dT%H%M%SZ).md"
mkdir -p docs/evidence/megaqml
{
  printf '# MegaQML Phase 2k isolated loader-focused triage\n\nSource SHA: %s\n\n' "$source_sha"
  printf 'Scope: exact reviewed Material/Waffle Cloud Storage page bodies with isolated visual stubs, copied Cloud Storage service/parser and Python-only fake static dispatcher. No real MEGAcmd, credentials, full Hadalis UI or live feature acceptance.\n\n'
  printf '| Test | Result | Exit code | Source SHA |\n|---|---|---:|---|\n'
  while IFS=, read -r name status code sha; do
    printf '| %s | %s | %s | %s |\n' "$name" "$status" "$code" "$sha"
  done < "$scratch/safe.csv"
  for name in quickshell_baseline quickshell_ui_material quickshell_ui_waffle; do
    if grep -q "^$name,FAIL," "$scratch/safe.csv"; then
      # Only the allowlisted category emitted by the reviewed classifier.
      grep '^quickshell_smoke_category=' "$scratch/$name.raw" || true
    fi
  done
  if [[ "$failed" != 0 ]]; then
    echo 'Aggregate: FAIL (source/fixture or UI loader checks failed).'
  elif [[ "$unqualified" != 0 ]]; then
    echo 'Aggregate: UNQUALIFIED (environment or prerequisite blocked UI checks).'
  else
    echo 'Aggregate: PASS (isolated fixture only; no full Hadalis render).'
  fi
} > "$report"

cat "$scratch/safe.csv"
printf 'SOURCE_SHA=%s\nSAFE_REPORT=%s\n' "$source_sha" "$report"
if [[ "$(git status --porcelain --untracked-files=all)" != "?? $report" ]]; then
  echo 'PUBLICATION_SKIPPED_DIRTY_WORKTREE'
  exit "$failed"
fi
# The report stays pinned to the tested source SHA. If Wull publishes
# concurrently, fast-forward only across explicitly reviewed Wull paths.
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
  echo 'PUBLICATION_SKIPPED_GIT_IDENTITY'
  exit "$failed"
fi
git add -- "$report"
if [[ "$(git diff --cached --name-only)" != "$report" ]] || ! git diff --cached --check; then
  git reset --quiet -- "$report"
  echo 'PUBLICATION_SKIPPED_INDEX'
  exit "$failed"
fi
if ! git commit --quiet -m "test(megaqml): Phase 2k isolated UI loader triage $(git rev-parse --short=12 HEAD)" -- "$report"; then
  echo 'PUBLICATION_SKIPPED_COMMIT'
  exit "$failed"
fi
local_commit="$(git rev-parse HEAD)"
if git push --quiet origin HEAD:refs/heads/dev; then
  printf 'PUBLICATION=PUSHED_SAFE_SUMMARY\nEVIDENCE_COMMIT=%s\n' "$local_commit"
else
  printf 'PUBLICATION=LOCAL_ONLY\nLOCAL_EVIDENCE_COMMIT=%s\n' "$local_commit"
fi
exit "$failed"
