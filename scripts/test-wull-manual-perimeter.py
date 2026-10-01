#!/usr/bin/env python3
"""Manual SHA-scoped Wull perimeter diagnosis (never an automated worker job)."""
import datetime
import json
import os
from pathlib import Path
import re
import secrets
import subprocess
import sys

BASE = "d24761531ed942e3283533123062bf93bdff0ffc"
SCRIPT = "scripts/test-wull-manual-perimeter.py"
CASES = [
    ("iris-production", 180, ["python3", "scripts/test-iris-production-surface-contract.py"]),
    ("connected-input", 180, ["python3", "scripts/test-connected-input-lifecycle.py"]),
    ("quick-notes", 180, ["python3", "scripts/test-quick-notes-corner-contract.py"]),
    ("wull-production", 180, ["python3", "scripts/test-wull-production-contract.py"]),
    ("perimeter-placement", 180, ["bash", "scripts/test-perimeter-compatibility-placement-contract.sh"]),
    ("perimeter-family", 300, ["bash", "scripts/test-perimeter-family-contracts.sh"]),
    ("perimeter-routes", 180, ["bash", "scripts/test-perimeter-route-contracts.sh"]),
    ("perimeter-settings", 180, ["bash", "scripts/test-perimeter-settings-contracts.sh"]),
    # source-contracts internally runs the shared-contracts test.
    ("perimeter-shared-and-source", 300, ["bash", "scripts/test-perimeter-source-contracts.sh"]),
    ("perimeter-retirement", 180, ["bash", "scripts/test-perimeter-retirement-contract.sh"]),
]

def git(*args):
    result = subprocess.run(["git", *args], capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError("Git check failed: " + " ".join(args))
    return result.stdout.strip()

def audit(before, after):
    if subprocess.run(["git", "merge-base", "--is-ancestor", before, after]).returncode:
        raise RuntimeError("dev history is not a fast-forward from the audited SHA")
    for path in git("diff", "--name-only", before, after).splitlines():
        if path.startswith(("docs/", "automation/")):
            continue
        if path.startswith("to-do/") and path != "to-do/cloud-bot/ABYSS_WATER_DROPLET_COMPANION.md":
            continue
        if path.startswith(("scripts/test-megaqml-", "services/deferred/CloudStorage")):
            continue
        if path in ("modules/settings/CloudStorageConfig.qml", "translations/en_US.json"):
            continue
        if path == SCRIPT:
            addition = git("log", "--reverse", "--diff-filter=A", "--format=%H",
                           BASE + ".." + after, "--", SCRIPT).splitlines()
            if not addition:
                raise RuntimeError("Diagnostic runner has no reviewed introduction")
            original = subprocess.run(["git", "show", addition[0] + ":" + SCRIPT],
                                      capture_output=True, check=True).stdout
            current = subprocess.run(["git", "show", after + ":" + SCRIPT],
                                     capture_output=True, check=True).stdout
            if original != current:
                raise RuntimeError("Diagnostic runner was modified after introduction")
            continue
        raise RuntimeError("Unreviewed change requires a new audit: " + path)

def fetch():
    git("fetch", "--quiet", "origin",
        "refs/heads/dev:refs/remotes/origin/dev")
    return git("rev-parse", "refs/remotes/origin/dev")

def clean():
    return not git("status", "--porcelain=v1", "--untracked-files=all")

def main():
    if Path.cwd().resolve() != Path(git("rev-parse", "--show-toplevel")).resolve():
        raise RuntimeError("Run from Hadalis repository root")
    if git("symbolic-ref", "--quiet", "--short", "HEAD") != "dev" or not clean():
        raise RuntimeError("Require clean working tree on dev")
    valid_urls = {
        "https://github.com/llocphann/Hadalis",
        "https://github.com/llocphann/Hadalis.git",
        "git@github.com:llocphann/Hadalis",
        "git@github.com:llocphann/Hadalis.git",
        "ssh://git@github.com/llocphann/Hadalis",
        "ssh://git@github.com/llocphann/Hadalis.git",
    }
    push_urls = git("remote", "get-url", "--push", "--all", "origin").splitlines()
    if git("remote", "get-url", "origin") not in valid_urls or len(push_urls) != 1 or push_urls[0] not in valid_urls:
        raise RuntimeError("Unexpected origin URL")
    remote = fetch()
    audit(BASE, remote)
    git("merge", "--ff-only", remote)
    if not clean():
        raise RuntimeError("Working tree changed during fast-forward")
    source = git("rev-parse", "HEAD")
    run_id = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ") + "-" + secrets.token_hex(4)
    log_dir = Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state"))) / "hadalis" / ("wull-" + run_id)
    log_dir.mkdir(mode=0o700, parents=True, exist_ok=False)
    print("EXACT_SOURCE_SHA:", source, flush=True)
    print("PRIVATE_LOG_DIRECTORY:", log_dir, flush=True)
    started = datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds")
    checks = []
    for name, timeout_seconds, args in CASES:
        logfile = log_dir / (name + ".log")
        t0 = datetime.datetime.now(datetime.timezone.utc)
        with logfile.open("wb") as output:
            try:
                result = subprocess.run(
                    ["timeout", "--signal=TERM", "--kill-after=5s",
                     str(timeout_seconds) + "s", *args],
                    stdout=output, stderr=subprocess.STDOUT
                )
                code = result.returncode
            except OSError:
                code = 125
                output.write(b"local_execution_error\n")
        duration = round((datetime.datetime.now(datetime.timezone.utc) - t0).total_seconds(), 2)
        size = logfile.stat().st_size
        # Complete bounded-duration raw logs stay private. Publish no log content.
        item = {
            "check": name, "exit_code": code, "duration_seconds": duration,
            "status": "pass" if code == 0 else ("timeout" if code == 124 else "failed"),
            "local_log_exceeds_1mib": size > 1048576,
        }
        if code and name == "perimeter-shared-and-source":
            # Read only a bounded diagnostic sample, never publish raw diagnostics.
            with logfile.open("rb") as stream:
                sample = stream.read(1048576).decode(errors="replace")
            if "FAIL: perimeter shared contract:" in sample:
                item["failure_component"] = "shared"
            elif "FAIL: perimeter source retirement contract:" in sample:
                item["failure_component"] = "source"
        checks.append(item)
        print(name + ": exit=" + str(code), flush=True)
    report = {
        "kind": "wull_manual_perimeter_component_diagnostics",
        "source_sha": source,
        "started_utc": started,
        "finished_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
        "status": "pass" if all(c["exit_code"] == 0 for c in checks) else "failed",
        "scope": "diagnostics_only",
        "canonical_validation": "not_run",
        "live_visual_acceptance": "not_run",
        "checks": checks,
        "raw_logs": "private_local_only",
    }
    local_summary = log_dir / "sanitized-summary.json"
    local_summary.write_text(json.dumps(report, indent=2) + "\n")
    print("DIAGNOSTIC:", report["status"], flush=True)
    if git("symbolic-ref", "--quiet", "--short", "HEAD") != "dev" or git("rev-parse", "HEAD") != source or not clean():
        raise RuntimeError("Local checkout changed; report kept privately")
    updated_remote = fetch()
    audit(source, updated_remote)
    git("merge", "--ff-only", updated_remote)
    if not clean():
        raise RuntimeError("Working tree changed; report kept privately")
    report["publication_parent_sha"] = git("rev-parse", "HEAD")
    path = Path("docs") / ("wull-manual-perimeter-" + run_id + "-" + source[:12] + ".json")
    if path.exists():
        raise RuntimeError("Report path already exists")
    path.write_text(json.dumps(report, indent=2) + "\n")
    git("add", "--", str(path))
    if git("diff", "--cached", "--name-only") != str(path) or git("diff", "--name-only"):
        raise RuntimeError("Unexpected staged/working changes; no commit")
    if git("ls-files", "--others", "--exclude-standard"):
        raise RuntimeError("Unexpected untracked files; no commit")
    git("commit", "-m", "test(wull): publish sanitized manual perimeter result", "--", str(path))
    # A concurrent ref update causes an ordinary non-fast-forward failure.
    git("push", "origin", "HEAD:refs/heads/dev")
    print("REPORT_PUBLISHED:", path, flush=True)
    print("REPORT_COMMIT:", git("rev-parse", "HEAD"), flush=True)

if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, subprocess.CalledProcessError) as error:
        print("STOP:", error, file=sys.stderr)
        print("If diagnostics executed, private logs and a sanitized local summary remain on disk.", file=sys.stderr)
        sys.exit(1)
