#!/usr/bin/env python3
"""Isolated real-git test for the exact bounded MegaQML publication tail."""
from pathlib import Path
import runpy
import shutil
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[1]
runner = (repo / "scripts/test-megaqml-phase2-local.sh").read_text("utf-8")
guard = repo / "scripts/test-megaqml-phase2p-history-guard.py"
assert runner.count("for push_attempt in 1 2 3; do") == 1
start = 'evidence_sha="$(git rev-parse HEAD)"'
assert runner.count(start) == 1
suffix = runner[runner.index(start):]
for marker in ('git merge --no-ff --no-edit',
               '"$source_sha" "$remote_sha"',
               '"$source_sha" "$(git rev-parse HEAD)"',
               'PUBLICATION_RETRY_UNREVIEWED_REMOTE',
               'PUBLICATION_RETRY_REPORT_COLLISION'):
    assert marker in suffix, marker
names = runpy.run_path(str(guard))["EXPECTED_TESTS"]


def git(folder, *args, check=True):
    child = subprocess.run(["git", "-C", str(folder), *args], text=True,
                           capture_output=True, timeout=8)
    if check and child.returncode:
        raise AssertionError(("git fixture failed", args, child.returncode))
    return child


def identity(folder):
    git(folder, "config", "user.name", "MegaQML Fixture")
    git(folder, "config", "user.email", "fixture@example.invalid")


def scenario(root, unsafe):
    root.mkdir()
    origin, seed, local, other = (
        root / "origin.git", root / "seed", root / "local", root / "other")
    subprocess.run(["git", "init", "-q", "--bare", str(origin)],
                   check=True, timeout=8, capture_output=True)
    git(origin, "symbolic-ref", "HEAD", "refs/heads/dev")
    subprocess.run(["git", "init", "-q", "-b", "dev", str(seed)],
                   check=True, timeout=8, capture_output=True)
    identity(seed)
    path = seed / "scripts" / guard.name
    path.parent.mkdir()
    shutil.copyfile(guard, path)
    git(seed, "add", "--", "scripts/" + guard.name)
    git(seed, "commit", "-qm", "synthetic baseline")
    source = git(seed, "rev-parse", "HEAD").stdout.strip()
    git(seed, "remote", "add", "origin", str(origin))
    git(seed, "push", "-q", "-u", "origin", "dev")
    for dest in (local, other):
        subprocess.run(["git", "clone", "-q", str(origin), str(dest)],
                       check=True, timeout=8, capture_output=True)
        identity(dest)

    relative = ("docs/evidence/megaqml/phase2p-" + source[:12]
                + "-20261001T170500Z.md")
    report = local / relative
    report.parent.mkdir(parents=True)
    mark = chr(96)
    report.write_text(
        "# MegaQML Phase 2p isolated repeatability evidence\n\n"
        "Source SHA: " + mark + source + mark + "\n\n"
        "| Test | Result | Exit code | Source SHA |\n"
        "|---|---|---:|---|\n"
        + "".join("| " + name + " | PASS | 0 | " + source + " |\n"
                  for name in names)
        + "race_repeat_attempts=8\nrace_repeat_passes=8\n"
        + "Aggregate: PASS (isolated synthetic tests only).\n",
        encoding="utf-8")
    git(local, "add", "--", relative)
    git(local, "commit", "-qm", "local verified report")
    evidence = git(local, "rev-parse", "HEAD").stdout.strip()

    changed = (other / "services/unreviewed.qml" if unsafe else
               other / "docs/wull-independent.md")
    changed.parent.mkdir(parents=True)
    changed.write_text("SYNTHETIC_MARKER_ONLY\n", encoding="utf-8")
    marker = str(changed.relative_to(other))
    git(other, "add", "--", marker)
    git(other, "commit", "-qm", "concurrent fixture edit")
    git(other, "push", "-q", "origin", "HEAD:refs/heads/dev")

    # Execute the exact production shell publication tail ONLY in temp Git.
    preface = (
        "set -euo pipefail\nfailed=0\nsource_sha=\"$1\"\nreport=\"$2\"\n"
        "fetch_remote_dev() {\n"
        "  git fetch --quiet --no-tags origin refs/heads/dev || return 1\n"
        "  remote_sha=\"$(git rev-parse FETCH_HEAD)\"\n"
        "}\n")
    outcome = subprocess.run(
        ["bash", "-c", preface + suffix, "fixture", source, relative],
        cwd=local, text=True, capture_output=True, timeout=18)
    assert outcome.returncode == 0, ("publication fixture failed", unsafe)
    tip = git(origin, "rev-parse", "refs/heads/dev").stdout.strip()
    assert git(origin, "cat-file", "-e", "refs/heads/dev:" + marker,
               check=False).returncode == 0
    if unsafe:
        assert "PUBLICATION_RETRY_UNREVIEWED_REMOTE" in outcome.stdout
        assert "PUBLICATION=LOCAL_ONLY" in outcome.stdout
        assert git(origin, "cat-file", "-e", "refs/heads/dev:" + relative,
                   check=False).returncode != 0
        assert git(local, "rev-parse", "HEAD").stdout.strip() == evidence
    else:
        assert "PUBLICATION=PUSHED_SAFE_SUMMARY" in outcome.stdout
        assert git(origin, "cat-file", "-e", "refs/heads/dev:" + relative,
                   check=False).returncode == 0
        assert git(local, "merge-base", "--is-ancestor", evidence, tip,
                   check=False).returncode == 0
        text = git(origin, "show", "refs/heads/dev:" + relative).stdout
        assert "Source SHA: " + mark + source + mark in text
        assert "race_repeat_passes=8" in text


with tempfile.TemporaryDirectory(prefix="megaqml-publication-") as tmp:
    base = Path(tmp)
    scenario(base / "safe", unsafe=False)
    scenario(base / "reject", unsafe=True)
print("PASS MegaQML push retry: concurrent Wull preserved, unsafe edit rejected")
