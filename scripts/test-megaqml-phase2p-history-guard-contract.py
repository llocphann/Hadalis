#!/usr/bin/env python3
"""Offline verification of strict Wull/evidence ancestry and fail-closed edits."""
from pathlib import Path
import os
import runpy
import shutil
import subprocess
import sys
import tempfile

repo = Path(__file__).resolve().parents[1]
guard = repo / "scripts/test-megaqml-phase2p-history-guard.py"
schema = runpy.run_path(str(guard))
names = schema["EXPECTED_TESTS"]
assert len(names) == 40 and len(set(names)) == 40
with tempfile.TemporaryDirectory(prefix="megaqml-ancestry-test-") as scratch:
    root = Path(scratch)
    (root / "scripts").mkdir()
    shutil.copyfile(guard, root / "scripts" / guard.name)

    def git(*args):
        return subprocess.check_output(["git", "-C", str(root), *args],
                                       stderr=subprocess.DEVNULL,
                                       text=True).strip()

    def inspect(base, tip, expected):
        child = subprocess.run(
            [sys.executable, str(root / "scripts" / guard.name), base, tip],
            cwd=root, capture_output=True, text=True, timeout=5)
        assert child.returncode == expected, (expected, child.returncode)
        assert child.stdout.strip() == (
            "REVIEWED_ANCESTRY_OK" if expected == 0 else "UNREVIEWED_CHANGE")
        assert child.stderr == ""

    git("init", "-q")
    git("config", "user.name", "Fixture")
    git("config", "user.email", "fixture@example.invalid")
    git("add", "--", "scripts/" + guard.name)
    git("commit", "-qm", "baseline")
    base = git("rev-parse", "HEAD")
    inspect(base, base, 0)

    (root / "docs").mkdir()
    (root / "docs/wull-safe.txt").write_text("Wull test only\n")
    git("add", "docs/wull-safe.txt")
    git("commit", "-qm", "allowed Wull edit")
    source = git("rev-parse", "HEAD")
    inspect(base, source, 0)

    folder = root / "docs/evidence/megaqml"
    folder.mkdir(parents=True)
    evidence = folder / ("phase2p-" + source[:12] + "-20261001T170000Z.md")
    mark = chr(96)
    evidence.write_text(
        "# MegaQML Phase 2p isolated repeatability evidence\n\n"
        "Source SHA: " + mark + source + mark + "\n\n"
        "| Test | Result | Exit code | Source SHA |\n"
        "|---|---|---:|---|\n" + "".join(
            "| " + name + " | PASS | 0 | " + source + " |\n"
            for name in names)
        + "race_repeat_attempts=8\nrace_repeat_passes=8\n"
        + "Aggregate: PASS (synthetic and isolated checks).\n")
    git("add", "docs/evidence")
    git("commit", "-qm", "verified report")
    tip = git("rev-parse", "HEAD")
    inspect(base, tip, 0)

    # No broad exemption: edits to an existing evidence file cannot pass.
    evidence.write_text(evidence.read_text().replace(
        "race_repeat_passes=8", "race_repeat_passes=7"))
    git("add", "docs/evidence")
    git("commit", "-qm", "tampered evidence")
    inspect(base, git("rev-parse", "HEAD"), 78)

    (root / "services").mkdir()
    (root / "services/unsafe.qml").write_text("PRIVATE_CANARY\n")
    git("add", "services/unsafe.qml")
    git("commit", "-qm", "unreviewed source")
    inspect(base, git("rev-parse", "HEAD"), 78)

    # Reject an invalid source claim even if the filename looks valid.
    # Verify only a fixed rejection status, never expose report contents.
    inspect("0" * 40, tip, 78)
print("PASS MegaQML strict evidence ancestry mock-git contract")
