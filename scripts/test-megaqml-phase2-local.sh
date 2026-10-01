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
remote_sha="$(git ls-remote origin refs/heads/dev | awk 'NR==1{print $1}')"
[[ "$remote_sha" == "$expected" ]] || { echo 'REMOTE_MISMATCH'; exit 68; }
scratch="$(mktemp -d)"
trap 'rm -rf -- "$scratch"' EXIT
failed=0
run_test() {
  local name="$1" code state; shift
  if "$@" > "$scratch/$name.raw" 2>&1; then code=0; state=PASS
  else code=$?; state=FAIL; failed=1; fi
  printf '%s,%s,%s,%s\n' "$name" "$state" "$code" "$source_sha" >> "$scratch/safe.csv"
}
run_test megaqml_phase2_contract python3 scripts/test-megaqml-phase2-contract.py
run_test settings_navigation python3 scripts/test-settings-information-architecture.py
run_test megaqml_waffle_navigation python3 scripts/test-megaqml-waffle-contract.py
run_test megaqml_static_protocol node scripts/test-megaqml-phase2-protocol.mjs
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
if command -v qmlformat >/dev/null 2>&1; then
  printf 'import QtQuick\nItem {}\n' > "$scratch/qt-minimal.qml"
  run_test qml_minimal qmlformat "$scratch/qt-minimal.qml"
  if grep -q '^qml_minimal,PASS,' "$scratch/safe.csv"; then
    run_test qml_baseline qmlformat modules/settings/OverviewConfig.qml
    if grep -q '^qml_baseline,PASS,' "$scratch/safe.csv"; then
      run_test qml_service qmlformat services/deferred/CloudStorageService.qml
      run_test qml_page qmlformat modules/settings/CloudStorageConfig.qml
    else
      printf 'qml_service,SKIP,127,%s\n' "$source_sha" >> "$scratch/safe.csv"
      printf 'qml_page,SKIP,127,%s\n' "$source_sha" >> "$scratch/safe.csv"
    fi
  else
    printf 'qml_baseline,SKIP,127,%s\n' "$source_sha" >> "$scratch/safe.csv"
    printf 'qml_service,SKIP,127,%s\n' "$source_sha" >> "$scratch/safe.csv"
    printf 'qml_page,SKIP,127,%s\n' "$source_sha" >> "$scratch/safe.csv"
  fi
else
  for case_name in qml_minimal qml_baseline qml_service qml_page; do
    printf '%s,SKIP,127,%s\n' "$case_name" "$source_sha" >> "$scratch/safe.csv"
  done
fi
report="docs/evidence/megaqml/phase2a-${source_sha:0:12}-$(date -u +%Y%m%dT%H%M%SZ).md"
mkdir -p docs/evidence/megaqml
{
  printf '# MegaQML Phase 2a synthetic local evidence\n\nSource SHA: `%s`\n\n' "$source_sha"
  printf 'Scope: static source contracts, synthetic parser cases and optional QML syntax parsing; no QML runtime or vendor/account execution. No vendor process, account, QML rendering or live acceptance.\n\n'
  printf '| Test | Result | Exit code | Source SHA |\n|---|---|---:|---|\n'
  while IFS=, read -r name state code sha; do
    printf '| %s | %s | %s | %s |\n' "$name" "$state" "$code" "$sha"
  done < "$scratch/safe.csv"
  for qt_case in qml_baseline qml_service qml_page; do
    if grep -q "^${qt_case},FAIL," "$scratch/safe.csv"; then
      python3 scripts/test-megaqml-qt-diagnostic.py "$qt_case" "$scratch/$qt_case.raw"
    fi
  done
  if grep -q '^qml_minimal,FAIL,' "$scratch/safe.csv"; then
    echo 'qml_blocker=tool_cannot_parse_minimal_qt'
  elif grep -q '^qml_baseline,FAIL,' "$scratch/safe.csv"; then
    echo 'qml_blocker=tool_cannot_parse_existing_repository_page'
  elif grep -q '^qml_minimal,SKIP,' "$scratch/safe.csv"; then
    echo 'qml_blocker=qmlformat_unavailable'
  fi
  if [[ "$failed" == 0 ]]; then echo 'Aggregate: PASS (synthetic only).'
  else echo 'Aggregate: FAIL (synthetic).'; fi
} > "$report"
cat "$scratch/safe.csv"
printf 'SOURCE_SHA=%s\nSAFE_REPORT=%s\n' "$source_sha" "$report"
if [[ "$(git status --porcelain --untracked-files=all)" != "?? $report" ]]; then
  echo 'PUBLICATION_SKIPPED_DIRTY_WORKTREE'; exit "$failed"
fi
remote_after="$(git ls-remote origin refs/heads/dev | awk 'NR==1{print $1}')"
if [[ "$remote_after" != "$expected" ]]; then
  echo 'PUBLICATION_SKIPPED_REMOTE_MOVED'; exit "$failed"
fi
if [[ -z "$(git config user.name || true)" || -z "$(git config user.email || true)" ]]; then
  echo 'PUBLICATION_SKIPPED_GIT_IDENTITY'; exit "$failed"
fi
git add -- "$report"
if [[ "$(git diff --cached --name-only)" != "$report" ]] || ! git diff --cached --check; then
  git reset --quiet -- "$report"
  echo 'PUBLICATION_SKIPPED_INDEX'; exit "$failed"
fi
if ! git commit --quiet -m "test(megaqml): Phase 2a synthetic evidence ${source_sha:0:12}" -- "$report"; then
  echo 'PUBLICATION_SKIPPED_COMMIT'; exit "$failed"
fi
evidence_sha="$(git rev-parse HEAD)"
if git push --quiet origin HEAD:refs/heads/dev; then
  printf 'PUBLICATION=PUSHED_SAFE_SUMMARY\nEVIDENCE_COMMIT=%s\n' "$evidence_sha"
else
  printf 'PUBLICATION=LOCAL_ONLY\nLOCAL_EVIDENCE_COMMIT=%s\n' "$evidence_sha"
fi
exit "$failed"
