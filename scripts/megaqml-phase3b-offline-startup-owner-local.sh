#!/usr/bin/env bash
# Explicit opt-in, single isolated startup diagnostic with fixed public reason.
# Run only from clean disposable dev clone, never current shared Wull worktree.
set -euo pipefail
umask 077
[[ $# == 2 &&
   "$1" == "--acknowledge-isolated-offline-startup-diagnostic" &&
   "$2" == "--publish-public-diagnostic-category" ]] || {
  echo STOP=EXPLICIT_ACK_REQUIRED; exit 64;
}
cd "$(git rev-parse --show-toplevel)"
[[ "$(git branch --show-current)" == dev ]] || { echo STOP=NOT_DEV; exit 65; }
[[ -z "$(git status --porcelain --untracked-files=all)" ]] || {
  echo STOP=DIRTY; exit 66;
}
remote="$(git remote get-url origin)"
case "$remote" in
  https://github.com/llocphann/Hadalis|https://github.com/llocphann/Hadalis.git|\
  git@github.com:llocphann/Hadalis|git@github.com:llocphann/Hadalis.git|\
  ssh://git@github.com/llocphann/Hadalis|ssh://git@github.com/llocphann/Hadalis.git) ;;
  *) echo STOP=REMOTE; exit 67 ;;
esac
[[ -n "$(git config user.name || true)" && -n "$(git config user.email || true)" ]] || {
  echo STOP=GIT_IDENTITY; exit 68;
}
sha="$(git rev-parse HEAD)"
prefix="$(printf %.12s "$sha")"
git fetch --quiet --no-tags origin refs/heads/dev || { echo STOP=FETCH; exit 69; }
tip="$(git rev-parse FETCH_HEAD)"
if [[ "$sha" != "$tip" ]]; then
  python3 scripts/test-megaqml-phase2p-history-guard.py "$sha" "$tip" \
    >/dev/null || { echo STOP=UNREVIEWED_REMOTE; exit 70; }
fi
python3 scripts/test-megaqml-phase3b-offline-startup-diagnostic.py || {
  echo STOP=FAKE_ONLY_DIAGNOSTIC; exit 71;
}
python3 scripts/megaqml-phase3b-offline-startup-diagnostic.py --self-test || {
  echo STOP=INERT_SELF_TEST; exit 72;
}
scratch="$(mktemp -d)"
trap 'rm -rf -- "$scratch"' EXIT
set +e
raw="$(python3 scripts/megaqml-phase3b-offline-startup-diagnostic.py \
  --acknowledge-isolated-offline-startup-diagnostic)"
rc=$?
set -e
[[ "$rc" == 20 || "$rc" == 21 ]] || { echo STOP=UNEXPECTED_DIAGNOSTIC_EXIT; exit 73; }
python3 - "$raw" > "$scratch/safe" <<'PY'
import json, sys
try:
    v = json.loads(sys.argv[1])
    assert type(v) is dict and set(v) == {
        "phase", "state", "reason", "sandbox_log_present",
        "sandbox_client_timed_out", "network_available", "account_used",
        "server_version_qualified", "live_capabilities_unlocked",
    }
    assert v["phase"] == "megaqml_phase3b_offline_startup_diagnostic"
    assert v["state"] == "UNQUALIFIED"
    for key in ("network_available", "account_used",
                "server_version_qualified", "live_capabilities_unlocked"):
        assert v[key] is False
    assert type(v["sandbox_log_present"]) is bool
    assert type(v["sandbox_client_timed_out"]) is bool
    assert v["reason"] in {
        "sandbox_server_log_absent", "sandbox_server_log_library_missing",
        "sandbox_server_log_socket_failure",
        "sandbox_server_log_permission_failure",
        "sandbox_server_log_network_event",
        "sandbox_server_log_other", "sandbox_supervisor_error",
        "sandbox_setup_unavailable", "sandbox_process_unavailable",
        "bounded_timeout", "bounded_output_cap", "missing_host_dependency",
        "mixed_vendor_bin_directories", "sandbox_supervisor_output_invalid",
        "do_not_run_as_root",
    }
    print(json.dumps(v, sort_keys=True, separators=(",", ":")))
except (AssertionError, ValueError, TypeError, KeyError):
    sys.exit("STOP=INVALID_DIAGNOSTIC_SUMMARY")
PY
safe="$(cat "$scratch/safe")"
echo "SOURCE_SHA=$sha"
echo "SAFE_SANDBOX_DIAGNOSTIC=$safe"
git fetch --quiet --no-tags origin refs/heads/dev || {
  echo PUBLICATION=FETCH_FAILED; exit 75;
}
tip="$(git rev-parse FETCH_HEAD)"
if [[ "$sha" != "$tip" ]]; then
  python3 scripts/test-megaqml-phase2p-history-guard.py "$sha" "$tip" \
    >/dev/null || { echo PUBLICATION=UNREVIEWED_REMOTE; exit 75; }
  git merge --ff-only "$tip" >/dev/null || {
    echo PUBLICATION=NOT_FAST_FORWARD; exit 75;
  }
fi
report="docs/evidence/megaqml/phase3b-startup-$prefix-$(date -u +%Y%m%dT%H%M%SZ).md"
[[ ! -e "$report" ]] || { echo PUBLICATION=COLLISION; exit 75; }
mkdir -p docs/evidence/megaqml
{
  printf '# MegaQML Phase 3b one-shot offline startup diagnosis\n\n'
  printf 'Source SHA: %s\n\n' "$sha"
  printf 'Scope: single owner-approved disposable offline bwrap startup diagnostic, freshly created private sandbox logs classified inside namespace, no raw logs or current account, no live capability authorization.\n\n'
  printf 'Fake-only gate: PASS\n\nInert self-test: PASS\n\n'
  printf 'Diagnostic exit: %s\n\nFixed-class summary: %s\n' "$rc" "$safe"
} > "$report"
[[ "$(git status --porcelain --untracked-files=all)" == "?? $report" ]] || {
  echo PUBLICATION=DIRTY; exit 75;
}
git add -- "$report"
[[ "$(git diff --cached --name-only)" == "$report" ]] || {
  echo PUBLICATION=UNEXPECTED_INDEX; exit 75;
}
git commit -qm "test(megaqml): one-shot offline sandbox startup category $prefix" || {
  echo PUBLICATION=COMMIT_FAILED; exit 75;
}
for attempt in 1 2 3; do
  if git push --quiet origin HEAD:refs/heads/dev; then
    echo PUBLICATION=PUSHED_SAFE_STARTUP_CATEGORY
    echo "REPORT=$report"
    exit 0
  fi
  git fetch --quiet --no-tags origin refs/heads/dev || break
  tip="$(git rev-parse FETCH_HEAD)"
  if git cat-file -e "$tip:$report" 2>/dev/null &&
      git show "$tip:$report" | cmp -s - "$report"; then
    echo PUBLICATION=ALREADY_PUBLISHED_SAFE_STARTUP_CATEGORY
    echo "REPORT=$report"
    exit 0
  fi
  python3 scripts/test-megaqml-phase2p-history-guard.py "$sha" "$tip" \
    >/dev/null || break
  [[ -z "$(git ls-tree -r --name-only "$tip" -- "$report")" ]] || break
  git merge --no-ff --no-edit \
    -m "merge(dev): preserve startup category and concurrent Wull" "$tip" \
    >/dev/null || { git merge --abort >/dev/null 2>&1 || true; break; }
  [[ -z "$(git status --porcelain --untracked-files=all)" ]] || break
done
echo PUBLICATION=LOCAL_ONLY_PUSH_FAILED
exit 75
