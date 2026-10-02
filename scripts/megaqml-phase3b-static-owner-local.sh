#!/usr/bin/env bash
# One-shot vendor-free static installed-package triage and sanitized GitHub note.
# Run ONLY from a clean disposable dev clone, never the shared Wull worktree.
set -euo pipefail
umask 077
[[ $# == 1 && "$1" == "--acknowledge-vendor-free-static-triage" ]] || {
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
source_sha="$(git rev-parse HEAD)"
prefix="$(printf %.12s "$source_sha")"
python3 scripts/test-megaqml-phase3b-static-package.py || {
  echo STOP=STATIC_FAKE_CONTRACT; exit 70;
}
scratch="$(mktemp -d)"
trap 'rm -rf -- "$scratch"' EXIT
# This Python script reads only package metadata; it never launches
# MEGAcmd, bubblewrap, package managers or a shell.
raw="$(python3 scripts/megaqml-phase3b-static-package.py \
  --acknowledge-vendor-free-static-triage)" || {
  echo STOP=STATIC_TRIAGE; exit 71;
}
python3 - "$raw" > "$scratch/summary.json" <<'PY'
import json
import re
import sys
try:
    v = json.loads(sys.argv[1])
    assert set(v) == {
        "phase", "state", "source", "package_version", "reason",
        "vendor_executed", "network_used", "account_used",
        "server_version_qualified", "live_capabilities_unlocked",
    }
    assert v["phase"] == "megaqml_phase3b_static_package_metadata"
    for key in ("vendor_executed", "network_used", "account_used",
                "server_version_qualified", "live_capabilities_unlocked"):
        assert v[key] is False
    if v["state"] == "PACKAGE_VERSION_OBSERVED":
        assert v["reason"] == "package_not_running_server"
        assert v["source"] in (
            "pacman_local_db", "dpkg_local_db", "nix_derivation_label")
        assert isinstance(v["package_version"], str)
        assert re.fullmatch(r"\d{1,3}(?:\.\d{1,3}){1,3}",
                            v["package_version"])
    else:
        assert v["state"] == "UNVERIFIED"
        assert v["reason"] in (
            "matching_system_binaries_not_confirmed",
            "installed_package_metadata_not_confirmed")
        assert v["source"] is None and v["package_version"] is None
    print(json.dumps(v, separators=(",", ":"), sort_keys=True))
except (TypeError, ValueError, KeyError, AssertionError):
    sys.exit("STOP=INVALID_STATIC_METADATA")
PY
safe="$(cat "$scratch/summary.json")"
echo "SOURCE_SHA=$source_sha"
echo "SAFE_STATIC_METADATA=$safe"
git fetch --quiet --no-tags origin refs/heads/dev || { echo STOP=FETCH; exit 72; }
tip="$(git rev-parse FETCH_HEAD)"
if [[ "$tip" != "$source_sha" ]]; then
  python3 scripts/test-megaqml-phase2p-history-guard.py \
    "$source_sha" "$tip" >/dev/null || { echo STOP=UNREVIEWED_REMOTE; exit 73; }
  git merge --ff-only "$tip" >/dev/null || { echo STOP=NOT_FAST_FORWARD; exit 73; }
fi
report="docs/evidence/megaqml/phase3b-static-$prefix-$(date -u +%Y%m%dT%H%M%SZ).md"
[[ ! -e "$report" ]] || { echo STOP=COLLISION; exit 74; }
mkdir -p docs/evidence/megaqml
{
  printf '# MegaQML Phase 3b static package metadata triage\n\n'
  printf 'Source SHA: %s\n\n' "$source_sha"
  printf 'Scope: local system package records only; no MEGA process, account, network, socket or runtime server version verification.\n\n'
  printf 'Static fake contract: PASS\n\nSafe result: %s\n' "$safe"
} > "$report"
[[ "$(git status --porcelain --untracked-files=all)" == "?? $report" ]] || {
  echo PUBLICATION=DIRTY; exit 75;
}
git add -- "$report"
[[ "$(git diff --cached --name-only)" == "$report" ]] || {
  echo PUBLICATION=UNEXPECTED_INDEX; exit 75;
}
git commit -qm "test(megaqml): sanitized vendor-free package metadata $prefix" || {
  echo PUBLICATION=COMMIT_FAILED; exit 75;
}
for attempt in 1 2 3; do
  if git push --quiet origin HEAD:refs/heads/dev; then
    echo PUBLICATION=PUSHED_SAFE_STATIC_REPORT
    echo "REPORT=$report"
    exit 0
  fi
  git fetch --quiet --no-tags origin refs/heads/dev || break
  tip="$(git rev-parse FETCH_HEAD)"
  if git cat-file -e "$tip:$report" 2>/dev/null &&
      git show "$tip:$report" | cmp -s - "$report"; then
    echo PUBLICATION=ALREADY_PUBLISHED_SAFE_STATIC_REPORT
    echo "REPORT=$report"
    exit 0
  fi
  python3 scripts/test-megaqml-phase2p-history-guard.py \
    "$source_sha" "$tip" >/dev/null || break
  [[ -z "$(git ls-tree -r --name-only "$tip" -- "$report")" ]] || break
  git merge --no-ff --no-edit \
    -m "merge(dev): preserve static MegaQML evidence and Wull" "$tip" \
    >/dev/null || {
      git merge --abort >/dev/null 2>&1 || true
      break
    }
  [[ -z "$(git status --porcelain --untracked-files=all)" ]] || break
done
echo PUBLICATION=LOCAL_ONLY_PUSH_FAILED
exit 75
