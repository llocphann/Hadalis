#!/usr/bin/env python3
"""One-shot isolated Quickshell bridge lifecycle proof (no user-config writes)."""
import datetime as dt
import json
import os
from pathlib import Path
import secrets
import selectors
import shutil
import signal
import subprocess
import sys
import tempfile
import time

ANCHOR = "a685acce3877372bfd99926985da980c3bb3b94d"
SELF = "scripts/wull-manual-bridge-smoke.py"
FIXTURE = "scripts/wull-fixtures/bridge-exit"
REVIEWED = {
    "modules/abyss/AbyssPerimeter.qml",
    "modules/abyss/companion/CompanionBridge.qml",
    FIXTURE + "/shell.qml",
    FIXTURE + "/fake-dispatch.py",
}
VALID_URLS = {
    "https://github.com/llocphann/Hadalis",
    "https://github.com/llocphann/Hadalis.git",
    "git@github.com:llocphann/Hadalis",
    "git@github.com:llocphann/Hadalis.git",
    "ssh://git@github.com/llocphann/Hadalis",
    "ssh://git@github.com/llocphann/Hadalis.git",
}
CAP = 1048576


def git(*args):
    result = subprocess.run(["git", *args], capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError("Git command failed: " + " ".join(args))
    return result.stdout.strip()


def clean():
    return not git("status", "--porcelain=v1", "--untracked-files=all")


def audit(after):
    if subprocess.run(["git", "merge-base", "--is-ancestor", ANCHOR, after],
                      capture_output=True).returncode:
        raise RuntimeError("dev is not a descendant of the reviewed fixture")
    changes = set(git("diff", "--name-only", ANCHOR, after).splitlines())
    affected = REVIEWED & changes
    if affected:
        raise RuntimeError("Reviewed Wull bridge or fixture changed: " + sorted(affected)[0])
    if SELF in changes:
        introduced = git("log", "--diff-filter=A", "--format=%H",
                         ANCHOR + ".." + after, "--", SELF).splitlines()
        if len(introduced) != 1:
            raise RuntimeError("Manual bridge runner revision needs review")
        original = subprocess.run(["git", "show", introduced[0] + ":" + SELF],
                                  check=True, capture_output=True).stdout
        current = subprocess.run(["git", "show", after + ":" + SELF],
                                 check=True, capture_output=True).stdout
        if original != current:
            raise RuntimeError("Manual bridge runner changed after its introduction")


def fetch():
    git("fetch", "--quiet", "origin",
        "refs/heads/dev:refs/remotes/origin/dev")
    return git("rev-parse", "refs/remotes/origin/dev")


def run_case(qs, kind, private_dir):
    case_dir = private_dir / kind
    case_dir.mkdir(mode=0o700)
    fixture_dir = case_dir / "fixture"
    (fixture_dir / "companion").mkdir(parents=True)
    (fixture_dir / "scripts").mkdir()
    shutil.copyfile(FIXTURE + "/shell.qml", fixture_dir / "shell.qml")
    shutil.copyfile("modules/abyss/companion/CompanionBridge.qml",
                    fixture_dir / "companion/CompanionBridge.qml")
    fake = fixture_dir / "scripts/native-dispatch"
    shutil.copyfile(FIXTURE + "/fake-dispatch.py", fake)
    fake.chmod(0o700)
    state_file = case_dir / "fake-start-count.private"
    isolated = case_dir / "xdg"
    for sub in ("config", "data", "cache", "state"):
        (isolated / sub).mkdir(parents=True)
    env = dict(os.environ)
    env.update({
        "XDG_CONFIG_HOME": str(isolated / "config"),
        "XDG_DATA_HOME": str(isolated / "data"),
        "XDG_CACHE_HOME": str(isolated / "cache"),
        "XDG_STATE_HOME": str(isolated / "state"),
        "QT_QPA_PLATFORM": "offscreen",
        "QS_NO_RELOAD_POPUP": "1",
        "INIR_COMPANIOND": "",
        "WULL_SMOKE_CASE": kind,
        "WULL_SMOKE_STATE": str(state_file),
    })
    log = case_dir / "quickshell.private.log"
    seen = set()
    patterns = {
        "WULL_BRIDGE_DISABLED_OK",
        "WULL_BRIDGE_EXIT_GATE_OK",
        "WULL_BRIDGE_RESTART_OK",
        "WULL_BRIDGE_FIXTURE_INVALID",
        "WULL_BRIDGE_FIXTURE_TIMEOUT",
    }
    truncated = False
    started = time.monotonic()
    code = 125
    # Continuously drain output; never let raw Quickshell diagnostics into Git.
    with log.open("wb") as output:
        try:
            proc = subprocess.Popen([qs, "--path", str(fixture_dir / "shell.qml")],
                                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                    env=env, start_new_session=True)
            saved = 0
            tail = b""
            timed_out = False
            with selectors.DefaultSelector() as watcher:
                watcher.register(proc.stdout, selectors.EVENT_READ)
                while watcher.get_map():
                    if time.monotonic() - started > 14:
                        try:
                            os.killpg(proc.pid, signal.SIGKILL)
                        except ProcessLookupError:
                            pass
                        timed_out = True
                        truncated = True
                        break
                    if not watcher.select(timeout=0.2):
                        continue
                    chunk = os.read(proc.stdout.fileno(), 65536)
                    if not chunk:
                        watcher.unregister(proc.stdout)
                        break
                    joint = tail + chunk
                    for pattern in patterns:
                        if pattern.encode() in joint:
                            seen.add(pattern)
                    tail = joint[-64:]
                    remaining = max(0, CAP - saved)
                    if remaining:
                        output.write(chunk[:remaining])
                        saved += min(len(chunk), remaining)
                    if len(chunk) > remaining:
                        truncated = True
            proc.stdout.close()
            try:
                observed = proc.wait(timeout=3)
                code = 124 if timed_out else observed
            except subprocess.TimeoutExpired:
                try:
                    os.killpg(proc.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                proc.wait()
                code = 124
                truncated = True
        except OSError:
            output.write(b"quickshell_local_execution_error\n")

    expected = ({"WULL_BRIDGE_DISABLED_OK"} if kind == "disabled" else
                {"WULL_BRIDGE_EXIT_GATE_OK", "WULL_BRIDGE_RESTART_OK"})
    count = int(state_file.read_text()) if state_file.exists() and (
        state_file.read_text().strip().isdigit()
    ) else 0
    successful = code == 0 and expected.issubset(seen) and not (
        {"WULL_BRIDGE_FIXTURE_INVALID", "WULL_BRIDGE_FIXTURE_TIMEOUT"} & seen
    ) and count == (0 if kind == "disabled" else 2)
    result = {
        "check": kind,
        "status": "pass" if successful else ("timeout" if code == 124 else "failed"),
        "exit_code": code,
        "duration_seconds": round(time.monotonic() - started, 2),
        "fake_backend_start_count": count,
        "private_log_truncated": truncated,
    }
    print(kind + ": " + result["status"], flush=True)
    return result


def main():
    os.umask(0o077)
    if Path.cwd().resolve() != Path(git("rev-parse", "--show-toplevel")).resolve():
        raise RuntimeError("Must run at the Hadalis repository root")
    if git("symbolic-ref", "--quiet", "--short", "HEAD") != "dev" or not clean():
        raise RuntimeError("Requires a clean dev checkout")
    push_urls = git("remote", "get-url", "--push", "--all", "origin").splitlines()
    if git("remote", "get-url", "origin") not in VALID_URLS or (
        len(push_urls) != 1 or push_urls[0] not in VALID_URLS
    ):
        raise RuntimeError("Unexpected Git remote")

    latest = fetch()
    audit(latest)
    git("merge", "--ff-only", latest)
    if not clean():
        raise RuntimeError("Source checkout changed")
    source = git("rev-parse", "HEAD")
    identifier = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    identifier += "-" + secrets.token_hex(4)
    state = Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state")))
    private_dir = state / "hadalis" / ("wull-bridge-" + identifier)
    private_dir.mkdir(mode=0o700, parents=True, exist_ok=False)
    print("EXACT_SOURCE_SHA:", source, flush=True)
    print("PRIVATE_LOG_DIRECTORY:", private_dir, flush=True)

    qs = shutil.which("qs") or shutil.which("quickshell")
    if qs is None:
        cases = [{"check": "quickshell-available", "status": "skipped",
                  "reason": "quickshell_not_found"}]
        result = "inconclusive"
    else:
        cases = [run_case(qs, name, private_dir)
                 for name in ("disabled", "exit-restart")]
        result = ("pass" if all(x["status"] == "pass" for x in cases)
                  else "failed")
    summary = {
        "kind": "wull_manual_isolated_bridge_lifecycle",
        "scope": "offscreen_fake_backend_only",
        "source_sha": source,
        "result": result,
        "canonical_validation": "not_run",
        "live_niri_host_acceptance": "not_run",
        "tests": cases,
        "private_logs": "local_only",
    }
    (private_dir / "sanitized-summary.json").write_text(
        json.dumps(summary, indent=2) + "\n"
    )
    if git("rev-parse", "HEAD") != source or not clean():
        raise RuntimeError("Local checkout changed; result kept privately")
    newer = fetch()
    audit(newer)
    git("merge", "--ff-only", newer)
    if not clean():
        raise RuntimeError("Unexpected source changes before publication")
    summary["publication_parent_sha"] = git("rev-parse", "HEAD")
    path = Path("docs") / ("wull-bridge-isolation-" + identifier
                           + "-" + source[:12] + ".json")
    if path.exists():
        raise RuntimeError("Report path already exists")
    path.write_text(json.dumps(summary, indent=2) + "\n")
    git("add", "--", str(path))
    if git("diff", "--cached", "--name-only") != str(path) or git("diff", "--name-only"):
        raise RuntimeError("Unexpected staged or working changes")
    if git("ls-files", "--others", "--exclude-standard"):
        raise RuntimeError("Unexpected untracked files")
    git("commit", "-m", "test(wull): publish sanitized isolated bridge lifecycle", "--",
        str(path))
    git("push", "origin", "HEAD:refs/heads/dev")
    print("BRIDGE_RESULT:", result, flush=True)
    print("REPORT_PUBLISHED:", path, flush=True)


if __name__ == "__main__":
    try:
        if sys.argv[1:]:
            raise RuntimeError("Usage: python3 scripts/wull-manual-bridge-smoke.py")
        main()
    except (RuntimeError, OSError, subprocess.CalledProcessError) as error:
        print("STOP:", error, file=sys.stderr)
        print("If executed, private logs and a local summary remain on disk.",
              file=sys.stderr)
        sys.exit(1)
