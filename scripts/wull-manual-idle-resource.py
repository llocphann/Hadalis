#!/usr/bin/env python3
"""Opt-in exact-source 60 s hidden-idle Rust Wull resource qualification.

Builds a unique private release binary; no desktop, user config, audio or input.
Raw logs stay private. Publishes only bounded aggregate metrics on clean dev.
"""
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
import time

BASE = "43b14c9fd4459ee6f8ffd852365d4483f1b21196"
SELF = "scripts/wull-manual-idle-resource.py"
CONTRACT = "scripts/test-wull-idle-resource-contract.py"
DURATION = 60
MAX_LOG = 1048576
ORIGINS = {
    "https://github.com/llocphann/Hadalis",
    "https://github.com/llocphann/Hadalis.git",
    "git@github.com:llocphann/Hadalis",
    "git@github.com:llocphann/Hadalis.git",
    "ssh://git@github.com/llocphann/Hadalis",
    "ssh://git@github.com/llocphann/Hadalis.git",
}


def git(*args):
    done = subprocess.run(["git", *args], capture_output=True, text=True,
                          timeout=45)
    if done.returncode:
        raise RuntimeError("Git operation failed: " + " ".join(args))
    return done.stdout.strip()


def clean():
    return git("status", "--porcelain=v1", "--untracked-files=all") == ""


def fetch():
    git("fetch", "--quiet", "origin", "refs/heads/dev:refs/remotes/origin/dev")
    return git("rev-parse", "refs/remotes/origin/dev")


def audit(commit):
    if subprocess.run(["git", "merge-base", "--is-ancestor", BASE, commit],
                      capture_output=True, timeout=10).returncode:
        raise RuntimeError("dev diverged from reviewed source")
    changes = set(git("diff", "--name-only", BASE, commit).splitlines())
    sensitive = [
        p for p in changes
        if p.startswith("native/inir-companiond/")
        or p in ("native/Cargo.toml", "native/Cargo.lock",
                 "scripts/native-dispatch", "AGENTS.md")
    ]
    if sensitive:
        raise RuntimeError("Native source changed; re-review required: "
                           + sorted(sensitive)[0])
    for path in (SELF, CONTRACT):
        revisions = git("log", "--format=%H", BASE + ".." + commit,
                        "--", path).splitlines()
        if len(revisions) != 1 or (
            git("rev-parse", revisions[0] + ":" + path)
            != git("rev-parse", commit + ":" + path)
        ):
            raise RuntimeError("Unreviewed resource runner/test revision")


def parse_ticks(raw):
    """Linux proc stat fields 14+15, robust to spaces/parentheses in comm."""
    rest = raw.rsplit(")", 1)
    if len(rest) != 2:
        raise ValueError("proc_stat_invalid")
    fields = rest[1].strip().split()  # field 3 is index 0
    if len(fields) <= 12:
        raise ValueError("proc_stat_short")
    return int(fields[11]) + int(fields[12])


def resource_snapshot(pid):
    root = Path("/proc") / str(pid)
    try:
        ticks = parse_ticks((root / "stat").read_text())
        rss = None
        for row in (root / "status").read_text().splitlines():
            if row.startswith("VmRSS:"):
                rss = int(row.split()[1])
                break
        return (rss, ticks) if rss is not None else None
    except (OSError, ValueError, IndexError):
        return None


class Lines:
    def __init__(self, stream):
        self.stream = stream
        self.buffer = bytearray()
        self.selector = selectors.DefaultSelector()
        self.selector.register(stream, selectors.EVENT_READ)

    def next(self, timeout):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            index = self.buffer.find(b"\n")
            if index >= 0:
                line = bytes(self.buffer[:index])
                del self.buffer[:index + 1]
                if len(line) > 8192:
                    raise ValueError("daemon_stdout_oversized")
                return json.loads(line)
            if not self.selector.select(max(0, deadline - time.monotonic())):
                break
            piece = os.read(self.stream.fileno(), 8192)
            if not piece:
                raise RuntimeError("daemon_stdout_closed")
            self.buffer.extend(piece)
            if len(self.buffer) > 16384:
                raise ValueError("daemon_stdout_overflow")
        raise TimeoutError("daemon_state_timeout")

    def unexpected_output(self, duration):
        count = int(bool(self.buffer))
        self.buffer.clear()
        if self.selector.select(duration):
            # Never publish arbitrary stdout contents.
            os.read(self.stream.fileno(), 8192)
            count += 1
        return count

    def close(self):
        self.selector.close()


def stop_owned(proc):
    if proc is None:
        return
    if proc.stdin:
        try:
            proc.stdin.close()
        except OSError:
            pass
    if proc.poll() is None:
        try:
            proc.wait(timeout=2)
        except subprocess.TimeoutExpired:
            # Never signal a reused group ID after its owner has exited.
            if proc.poll() is None:
                try:
                    os.killpg(proc.pid, signal.SIGTERM)
                except ProcessLookupError:
                    pass
            try:
                proc.wait(timeout=3)
            except subprocess.TimeoutExpired:
                if proc.poll() is None:
                    try:
                        os.killpg(proc.pid, signal.SIGKILL)
                    except ProcessLookupError:
                        pass
                proc.wait(timeout=3)


def private_owned_pids(binary):
    exe = str(binary.resolve())
    result = []
    for item in Path("/proc").iterdir():
        if not item.name.isdigit():
            continue
        try:
            if os.readlink(item / "exe") == exe:
                result.append(int(item.name))
        except (OSError, PermissionError):
            continue
    return result


def qualify(binary, folder):
    result = {
        "status": "failed", "reason": None,
        "initial_hidden": False, "accepted_show": False,
        "accepted_hide": False, "hidden_observation_seconds": DURATION,
        "sample_count": 0, "peak_rss_kib": None,
        "rss_growth_kib": None, "idle_cpu_seconds": None,
        "unrequested_hidden_stdout_reads": None,
        "single_owned_daemon": False, "owned_daemon_stopped": False,
        "rss_budget_kib": 32768, "max_rss_growth_kib": 4096,
        "max_idle_cpu_seconds": 0.5,
    }
    proc = None
    reader = None
    samples = []
    ticks = []
    unsolicited = 0
    clock_ticks = os.sysconf("SC_CLK_TCK")
    try:
        with (folder / "daemon-stderr.private.log").open("wb") as stderr:
            proc = subprocess.Popen(
                [str(binary)], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                stderr=stderr, start_new_session=True
            )
            reader = Lines(proc.stdout)
            first = reader.next(5)
            result["initial_hidden"] = (
                first.get("v") == 1 and first.get("type") == "state"
                and first.get("visibility") == "hidden"
            )
            if not result["initial_hidden"]:
                raise RuntimeError("unexpected_initial_state")
            proc.stdin.write(b'{"v":1,"seq":1,"type":"event","event":"show"}\n')
            proc.stdin.flush()
            shown = reader.next(5)
            result["accepted_show"] = (
                shown.get("type") == "state"
                and shown.get("visibility") == "present"
                and shown.get("seq", 0) > first.get("seq", -1)
            )
            if not result["accepted_show"]:
                raise RuntimeError("show_handshake_invalid")
            proc.stdin.write(b'{"v":1,"seq":2,"type":"event","event":"hide"}\n')
            proc.stdin.flush()
            # A scheduled animation state may precede the hide acknowledgment.
            for _ in range(8):
                hidden = reader.next(5)
                if hidden.get("visibility") == "hidden":
                    result["accepted_hide"] = (
                        hidden.get("type") == "state"
                        and hidden.get("seq", 0) > shown["seq"]
                    )
                    break
            if not result["accepted_hide"]:
                raise RuntimeError("hide_handshake_invalid")
            if len(private_owned_pids(binary)) != 1:
                raise RuntimeError("duplicate_or_missing_daemon")
            result["single_owned_daemon"] = True
            for index in range(13):
                if proc.poll() is not None:
                    raise RuntimeError("daemon_exited_during_hidden_idle")
                snapshot = resource_snapshot(proc.pid)
                if snapshot is None:
                    raise RuntimeError("proc_sampling_unavailable")
                rss, cpu = snapshot
                samples.append(rss)
                ticks.append(cpu)
                if index < 12:
                    unsolicited += reader.unexpected_output(5)
            result["sample_count"] = len(samples)
            result["peak_rss_kib"] = max(samples)
            result["rss_growth_kib"] = max(0, max(samples) - samples[0])
            result["idle_cpu_seconds"] = round(
                max(0, ticks[-1] - ticks[0]) / clock_ticks, 4
            )
            result["unrequested_hidden_stdout_reads"] = unsolicited
            if (max(samples) <= 32768
                    and result["rss_growth_kib"] <= 4096
                    and result["idle_cpu_seconds"] <= 0.5
                    and unsolicited == 0
                    and len(private_owned_pids(binary)) == 1):
                result["status"] = "pass"
            else:
                result["reason"] = "hidden_idle_resource_or_silence_budget_exceeded"
    except (OSError, RuntimeError, ValueError, TimeoutError, json.JSONDecodeError) as exc:
        # Predefined categories only; no private stdout/stderr in report.
        result["reason"] = (
            str(exc) if str(exc) in {
                "unexpected_initial_state", "show_handshake_invalid",
                "hide_handshake_invalid", "duplicate_or_missing_daemon",
                "daemon_exited_during_hidden_idle",
                "proc_sampling_unavailable", "daemon_state_timeout",
                "daemon_stdout_closed", "daemon_stdout_oversized",
                "daemon_stdout_overflow"
            } else "private_measurement_unavailable"
        )
    finally:
        if reader is not None:
            reader.close()
        stop_owned(proc)
        result["owned_daemon_stopped"] = len(private_owned_pids(binary)) == 0
        if not result["owned_daemon_stopped"]:
            result["status"] = "failed"
            result["reason"] = "private_daemon_cleanup_unproven"
    return result


def publish(report, path):
    for attempt in range(4):
        pushed = subprocess.run(["git", "push", "origin", "HEAD:refs/heads/dev"],
                                capture_output=True, timeout=50)
        if pushed.returncode == 0:
            return
        if attempt == 3:
            raise RuntimeError("Publication refused; own report remains local")
        if not clean() or git("diff-tree", "--no-commit-id", "--name-only",
                              "-r", "HEAD") != str(path):
            raise RuntimeError("Cannot safely rebase other changes")
        parent = git("rev-parse", "HEAD^")
        newer = fetch()
        audit(newer)
        if subprocess.run(["git", "merge-base", "--is-ancestor", parent, newer],
                          capture_output=True, timeout=10).returncode:
            raise RuntimeError("Unexpected remote history")
        git("rebase", "--onto", newer, parent)
        if not clean() or git("diff-tree", "--no-commit-id", "--name-only",
                              "-r", "HEAD") != str(path):
            raise RuntimeError("Unpublished report changed on rebase")
        report["publication_parent_sha"] = git("rev-parse", "HEAD^")
        path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        git("add", "--", str(path))
        if git("diff", "--cached", "--name-only") != str(path):
            raise RuntimeError("Unexpected staged report files")
        git("commit", "--amend", "--no-edit")


def main():
    os.umask(0o077)
    if sys.argv[1:] != ["--acknowledge-idle-measurement"]:
        raise RuntimeError("Explicit opt-in required: --acknowledge-idle-measurement")
    root = Path(git("rev-parse", "--show-toplevel")).resolve()
    if Path.cwd().resolve() != root or (
        git("symbolic-ref", "--quiet", "--short", "HEAD") != "dev"
    ) or not clean():
        raise RuntimeError("Requires clean dev at repository root")
    origin = git("remote", "get-url", "origin")
    push_urls = git("remote", "get-url", "--push", "--all", "origin").splitlines()
    if origin not in ORIGINS or len(push_urls) != 1 or push_urls[0] not in ORIGINS:
        raise RuntimeError("Unexpected origin remote")
    remote = fetch()
    audit(remote)
    git("merge", "--ff-only", remote)
    if not clean():
        raise RuntimeError("Working tree modified by fast-forward")
    source = git("rev-parse", "HEAD")
    uid = (dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
           + "-" + secrets.token_hex(4))
    state = Path(os.environ.get(
        "XDG_STATE_HOME", str(Path.home() / ".local/state")
    )).resolve()
    private = state / "hadalis" / ("wull-hidden-idle-" + uid)
    if root == private or root in private.parents:
        raise RuntimeError("Private logs must be outside the checkout")
    private.mkdir(mode=0o700, parents=True, exist_ok=False)
    print("EXACT_SOURCE_SHA:", source, flush=True)
    print("PRIVATE_LOG_DIRECTORY:", private, flush=True)
    binary = private / "cargo-target" / "release" / "inir-companiond"
    result = None
    cargo = shutil.which("cargo")
    if not sys.platform.startswith("linux") or cargo is None:
        result = {"status": "inconclusive",
                  "reason": "required_linux_or_cargo_unavailable"}
    else:
        build_env = dict(os.environ)
        build_env["CARGO_TARGET_DIR"] = str(private / "cargo-target")
        try:
            with (private / "cargo-build.private.log").open("wb") as log:
                build = subprocess.run(
                    [cargo, "build", "--locked", "--release",
                     "--manifest-path", "native/Cargo.toml",
                     "-p", "inir-companiond"],
                    env=build_env, stdout=log, stderr=subprocess.STDOUT,
                    timeout=900
                )
            if build.returncode or not binary.is_file():
                result = {"status": "inconclusive",
                          "reason": "private_release_build_failed"}
            else:
                result = qualify(binary, private)
        except (OSError, subprocess.TimeoutExpired):
            result = {"status": "inconclusive",
                      "reason": "private_release_build_unavailable"}
    report = {
        "kind": "wull_manual_private_rust_hidden_idle_resource",
        "source_sha": source, "status": result["status"], "measurement": result,
        "scope": "standalone_private_rust_daemon_60s_hidden_idle",
        "production_qml_cpu_memory": "not_measured",
        "live_visual_and_input_acceptance": "not_run",
        "canonical_validation": "not_run", "private_logs": "local_only",
    }
    print("WULL_IDLE_RESOURCE_RESULT:", report["status"], flush=True)
    if not clean() or git("rev-parse", "HEAD") != source:
        raise RuntimeError("Checkout changed during private measurement")
    newer = fetch()
    audit(newer)
    git("merge", "--ff-only", newer)
    if not clean():
        raise RuntimeError("Checkout changed before report publication")
    report["publication_parent_sha"] = git("rev-parse", "HEAD")
    path = Path("docs") / (
        "wull-idle-resource-" + uid + "-" + source[:12] + ".json"
    )
    if path.exists():
        raise RuntimeError("Report path exists")
    path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    git("add", "--", str(path))
    if (git("diff", "--cached", "--name-only") != str(path)
            or git("diff", "--name-only")
            or git("ls-files", "--others", "--exclude-standard")):
        raise RuntimeError("Unexpected files before publishing resource report")
    git("commit", "-m", "test(wull): publish bounded private Rust hidden-idle resource proof",
        "--", str(path))
    publish(report, path)
    print("REPORT_PUBLISHED:", path, flush=True)


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError, ValueError, subprocess.TimeoutExpired) as exc:
        print("STOP:", exc, file=sys.stderr)
        sys.exit(1)
