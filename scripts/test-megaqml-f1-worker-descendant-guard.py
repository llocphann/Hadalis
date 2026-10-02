#!/usr/bin/env python3
"""Offline real-Git contract for detached private F1 ancestry validation."""
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

SOURCE = Path(__file__).resolve().parent / "megaqml-f1-worker-descendant-guard.py"


def run(*args, cwd, allowed=(0,)):
    proc = subprocess.run(
        args, cwd=cwd, capture_output=True, check=False, timeout=12
    )
    assert proc.returncode in allowed, (args[:2], proc.returncode)
    return proc


with tempfile.TemporaryDirectory(prefix="megaqml-worker-ancestry-fake-") as temp:
    root = Path(temp)
    (root / "scripts").mkdir()
    shutil.copyfile(SOURCE, root / "scripts" / SOURCE.name)

    def git(*args):
        return run("git", *args, cwd=root).stdout.decode().strip()

    def check(pin, remote, want):
        r = run(
            sys.executable, str(root / "scripts" / SOURCE.name),
            pin, remote, cwd=root, allowed=(0, 78)
        )
        assert r.returncode == (0 if want else 78)
        assert r.stdout == (
            b"WORKER_DESCENDANT_OK\n" if want
            else b"WORKER_DESCENDANT_REJECTED\n"
        )
        assert r.stderr == b""

    def commit_file(path, body):
        target = root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(body)
        git("add", "--", path)
        git("commit", "-qm", "fake-only")

    def detached_at(pin):
        git("checkout", "-q", "--detach", pin)
        git("fetch", "-q", ".", "refs/heads/dev")
        return git("rev-parse", "FETCH_HEAD")

    git("init", "-q", "-b", "dev")
    git("config", "user.name", "Fixture")
    git("config", "user.email", "fixture@example.invalid")
    (root / "to-do/cloud-bot").mkdir(parents=True)
    (root / "to-do/cloud-bot/CLOUD_STORAGE.md").write_text("initial notes")
    git("add", "--", "scripts", "to-do/cloud-bot/CLOUD_STORAGE.md")
    git("commit", "-qm", "source")
    pin = git("rev-parse", "HEAD")
    assert detached_at(pin) == pin
    check(pin, pin, True)
    # Any named branch is forbidden even when its bytes match the source.
    git("switch", "-q", "dev")
    check(pin, pin, False)
    commit_file("automation/queue/pending/JOB-MEGAQML-FAKE-001.json", "{}")
    commit_file("automation/results/JOB-MEGAQML-FAKE-001.json", "{}")
    commit_file("docs/wull-visual/rotation.md", "fixture")
    commit_file("to-do/cloud-bot/CLOUD_STORAGE.md", "notes")
    allowed = detached_at(pin)
    check(pin, allowed, True)

    # Modifying an existing queue/receipt or changing executable source
    # must fail even if only the source SHA's descendant advanced.
    # Independent forbidden-source branch from the accepted fixture.
    git("branch", "source-case", allowed)
    git("switch", "-q", "source-case")
    commit_file("services/deferred/CloudStorageService.qml", "fake source changed")
    changed_source = git("rev-parse", "HEAD")
    git("checkout", "-q", "--detach", pin)
    git("fetch", "-q", ".", "refs/heads/source-case")
    check(pin, changed_source, False)

    # A later receipt modification must fail even when the aggregate diff
    # still shows that path as newly added.
    git("switch", "-q", "dev")
    commit_file("automation/results/JOB-MEGAQML-FAKE-001.json", '{"altered":1}')
    modified = detached_at(pin)
    check(pin, modified, False)
    check("0" * 40, changed_source, False)
    check(pin, "1" * 40, False)
    print("PASS detached worker descendant allows added receipts/Wull docs only; rejects edits")
