#!/usr/bin/env python3
"""Finite, no-vendor ancestry gate for SHA-pinned detached F1 worker clones.

This is for private --local-only tests ONLY. It cannot authorize publication,
runtime deployment, vendor execution, cloud reads or account mutations.
"""
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
SHA = re.compile(r"[0-9a-f]{40}\Z")
JOB = re.compile(
    r"automation/(?:queue/pending|results)/JOB-MEGAQML-[A-Z0-9-]+\.json\Z"
)
MAX_CHANGED_BYTES = 65536
MAX_CHANGED_FILES = 128


def git(*args):
    try:
        return subprocess.run(
            ["git", "-C", str(ROOT), *args],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            timeout=15,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None


def wull(path):
    return path.startswith((
        "docs/wull-", "scripts/wull-", "scripts/test-wull-", "modules/abyss/"
    )) or path in (
        "docs/WULL_NESTED_POINTER_ACCEPTANCE_DESIGN.md",
        "to-do/cloud-bot/ABYSS_WATER_DROPLET_COMPANION.md",
    )


def accepted(older, newer):
    if SHA.fullmatch(older) is None or SHA.fullmatch(newer) is None:
        return False
    actual = git("rev-parse", "--verify", "HEAD")
    branch = git("symbolic-ref", "-q", "--short", "HEAD")
    fetched = git("rev-parse", "--verify", "FETCH_HEAD")
    if (actual is None or actual.returncode != 0
            or actual.stdout.strip() != older.encode()
            or branch is None or branch.returncode != 1
            or fetched is None or fetched.returncode != 0
            or fetched.stdout.strip() != newer.encode()):
        return False
    ancestry = git("merge-base", "--is-ancestor", older, newer)
    if ancestry is None or ancestry.returncode != 0:
        return False
    # Inspect EACH intervening commit, never only its aggregate diff:
    # a reverted source edit or a modified receipt remains unreviewed.
    chain = git("rev-list", "--reverse", older + ".." + newer)
    if chain is None or chain.returncode != 0 or len(chain.stdout) > 8192:
        return False
    commits = chain.stdout.split()
    if len(commits) > 64:
        return False
    previous = older.encode()
    observed_files = 0
    for commit in commits:
        if SHA.fullmatch(commit.decode("ascii", "ignore")) is None:
            return False
        parents = git("rev-list", "--parents", "-n", "1", commit.decode("ascii"))
        if (parents is None or parents.returncode != 0
                or parents.stdout.split() != [commit, previous]):
            # Reject merges rather than admitting unchecked ancestry.
            return False
        changed = git("diff", "--name-status", "-z",
                      previous.decode("ascii"), commit.decode("ascii"), "--")
        if changed is None or changed.returncode != 0:
            return False
        raw = changed.stdout
        if len(raw) > MAX_CHANGED_BYTES or (raw and not raw.endswith(b"\0")):
            return False
        parts = raw[:-1].split(b"\0") if raw else []
        observed_files += len(parts) // 2
        if len(parts) % 2 != 0 or observed_files > MAX_CHANGED_FILES:
            return False
        for index in range(0, len(parts), 2):
            try:
                status = parts[index].decode("ascii")
                path = parts[index + 1].decode("utf-8")
            except UnicodeDecodeError:
                return False
            if status == "A" and JOB.fullmatch(path):
                continue
            if status == "M" and path == "to-do/cloud-bot/CLOUD_STORAGE.md":
                continue
            if status in ("A", "M", "D") and wull(path):
                continue
            # Reject source changes, modified/deleted receipts and renames
            # even when subsequent commits revert them.
            return False
        previous = commit
    return previous == newer.encode()


if __name__ == "__main__":
    ok = len(sys.argv) == 3 and accepted(sys.argv[1], sys.argv[2])
    print("WORKER_DESCENDANT_OK" if ok else "WORKER_DESCENDANT_REJECTED")
    raise SystemExit(0 if ok else 78)
