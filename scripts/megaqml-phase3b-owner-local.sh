#!/usr/bin/env bash
# Owner-only isolated MEGAcmd version test and allowlisted private dev report.
set -euo pipefail
umask 077
[[ $# == 1 && "$1" == "--acknowledge-disposable-offline-probe" ]] || { echo STOP=ACK_REQUIRED; exit 64; }
cd "$(git rev-parse --show-toplevel)"
[[ "$(git branch --show-current)" == dev ]] || { echo STOP=NOT_DEV; exit 65; }
[[ -z "$(git status --porcelain --untracked-files=all)" ]] || { echo STOP=DIRTY; exit 66; }
origin="$(git remote get-url origin)"
case "$origin" in
  https://github.com/llocphann/Hadalis|https://github.com/llocphann/Hadalis.git|\
  git@github.com:llocphann/Hadalis|git@github.com:llocphann/Hadalis.git|\
  ssh://git@github.com/llocphann/Hadalis|ssh://git@github.com/llocphann/Hadalis.git) ;;
  *) echo STOP=REMOTE; exit 67 ;;
esac
[[ -n "$(git config user.name || true)" && -n "$(git config user.email || true)" ]] || {
  echo STOP=GIT_IDENTITY; exit 68;
}
source_sha="$(git rev-parse HEAD)"
short_sha="$(printf '%.12s' "$source_sha")"
git fetch --quiet --no-tags origin refs/heads/dev || { echo STOP=FETCH; exit 69; }
remote_sha="$(git rev-parse FETCH_HEAD)"
if [[ "$remote_sha" != "$source_sha" ]]; then
  python3 scripts/test-megaqml-phase2p-history-guard.py \
    "$source_sha" "$remote_sha" >/dev/null || { echo STOP=REMOTE_CHANGED; exit 70; }
fi
python3 scripts/test-megaqml-phase3b-probe-contract.py || { echo STOP=CONTRACT; exit 71; }
python3 scripts/megaqml-manual-disposable-version-probe.py --self-test || {
  echo STOP=SELFTEST; exit 72;
}
scratch="$(mktemp -d)"
trap 'rm -rf -- "$scratch"' EXIT
set +e
raw="$(python3 scripts/megaqml-manual-disposable-version-probe.py \
  --acknowledge-disposable-offline-probe)"
rc=$?
set -e
[[ "$rc" == 0 || "$rc" == 20 || "$rc" == 21 ]] || { echo STOP=PROBE_EXIT; exit 73; }
python3 - "$raw" "$rc" > "$scratch/summary" <<'PY'
import json, re, sys
try:
    v = json.loads(sys.argv[1]); rc = int(sys.argv[2])
    assert set(v) == {"phase", "state", "vendor_version", "reason",
                      "network_available", "account_used", "live_capabilities_unlocked"}
    assert v["phase"] == "megaqml_phase3b_offline_installed_version"
    assert all(v[k] is False for k in ("network_available", "account_used",
                                      "live_capabilities_unlocked"))
    assert (v["state"], rc) in (("BLOCKED", 20), ("UNQUALIFIED", 21),
                                ("VERSION_OBSERVED_OFFLINE", 0))
    assert v["reason"] in {
        "do_not_run_as_root",
        "vendor_dependencies_missing_or_outside_allowed_roots",
        "mixed_vendor_bin_directories", "bubblewrap_or_smoke_tool_missing",
        "sandbox_setup_unavailable", "sandbox_process_unavailable",
        "bounded_timeout", "bounded_output_cap", "vendor_exit_nonzero",
        "vendor_version_format_unrecognized",
        "still_requires_installed_help_and_disposable_fixture_qualification",
    }
    if rc == 0:
        assert v["reason"] == (
            "still_requires_installed_help_and_disposable_fixture_qualification")
        assert isinstance(v["vendor_version"], str)
        assert re.fullmatch(r"\d{1,3}(?:\.\d{1,3}){1,3}", v["vendor_version"])
    else:
        assert v["vendor_version"] is None
    print(json.dumps(v, sort_keys=True, separators=(",", ":")))
except (ValueError, TypeError, KeyError, AssertionError):
    sys.exit("STOP=INVALID_SANITIZED_SUMMARY")
PY
safe="$(cat "$scratch/summary")"
echo "SOURCE_SHA=$source_sha"
echo "SANITIZED_RESULT=$safe"
report="docs/evidence/megaqml/phase3b-$short_sha-$(date -u +%Y%m%dT%H%M%SZ).md"
[[ ! -e "$report" ]] || { echo STOP=COLLISION; exit 74; }
mkdir -p docs/evidence/megaqml
{
  printf '# MegaQML Phase 3b isolated installed-version evidence\n\n'
  printf 'Source SHA: %s\n\n' "$source_sha"
  printf 'Scope: owner-approved, networkless disposable sandbox; no current account, login, cloud read/write, or raw vendor diagnostics.\n\n'
  printf 'Fake-only contract: PASS\n\nSelf-test: PASS\n\n'
  printf 'Probe exit: %s\n\nSanitized result: %s\n' "$rc" "$safe"
} > "$report"
git fetch --quiet --no-tags origin refs/heads/dev || { echo PUBLICATION=FETCH_BLOCKED; exit 75; }
remote_sha="$(git rev-parse FETCH_HEAD)"
if [[ "$remote_sha" != "$source_sha" ]]; then
  python3 scripts/test-megaqml-phase2p-history-guard.py \
    "$source_sha" "$remote_sha" >/dev/null || { echo PUBLICATION=REMOTE_BLOCKED; exit 75; }
  [[ -z "$(git ls-tree -r --name-only "$remote_sha" -- "$report")" ]] || {
    echo PUBLICATION=COLLISION; exit 75;
  }
  git merge --ff-only "$remote_sha" >/dev/null || { echo PUBLICATION=MERGE_BLOCKED; exit 75; }
fi
[[ "$(git status --porcelain --untracked-files=all)" == "?? $report" ]] || {
  echo PUBLICATION=DIRTY; exit 75;
}
git add -- "$report"
[[ "$(git diff --cached --name-only)" == "$report" ]] || {
  echo PUBLICATION=INDEX; exit 75;
}
git commit -qm "test(megaqml): sanitized offline version evidence $short_sha" || {
  echo PUBLICATION=COMMIT; exit 75;
}
for attempt in 1 2 3; do
  if git push --quiet origin HEAD:refs/heads/dev; then
    echo PUBLICATION=PUSHED_SAFE_SUMMARY
    echo "REPORT=$report"
    exit 0
  fi
  git fetch --quiet --no-tags origin refs/heads/dev || break
  remote_sha="$(git rev-parse FETCH_HEAD)"
  git merge-base --is-ancestor "$source_sha" "$remote_sha" || break
  python3 scripts/test-megaqml-phase2p-history-guard.py \
    "$source_sha" "$remote_sha" >/dev/null || break
  [[ -z "$(git ls-tree -r --name-only "$remote_sha" -- "$report")" ]] || break
  git merge --no-ff --no-edit \
    -m "merge(dev): retain sanitized MegaQML evidence and Wull" \
    "$remote_sha" >/dev/null || {
    git merge --abort >/dev/null 2>&1 || true
    break
  }
  [[ -z "$(git status --porcelain --untracked-files=all)" ]] || break
done
echo PUBLICATION=LOCAL_ONLY_PUSH_FAILED
exit 75
