#!/usr/bin/env python3
"""Manual, SHA-scoped Wull native/canonical qualification; never enables Wull."""
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

APPROVED_SOURCE = "9a8139da082b931db92a9719c8d0426e94233d9f"
SELF = "scripts/wull-manual-qualification.py"
MAX_LOG = 1048576


def stop(message):
    raise RuntimeError(message)


def git(*args):
    result = subprocess.run(["git", *args], stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE, text=True)
    if result.returncode:
        stop("Git command failed: " + " ".join(args))
    return result.stdout.strip()


def source_sensitive(path):
    if path == SELF:
        return False
    return (
        path.startswith(("native/inir-companiond/", "modules/abyss/companion/"))
        or path in {
            "native/Cargo.toml", "native/Cargo.lock",
            "modules/abyss/AbyssPerimeter.qml", "modules/common/Config.qml",
            "defaults/config.json", "scripts/native-dispatch",
            "scripts/test-wull-production-contract.py", "Makefile",
            "scripts/validate-maintainer-local.sh",
        }
        or path.startswith("scripts/test-perimeter-")
    )


def audit(after):
    if subprocess.run(["git", "merge-base", "--is-ancestor", APPROVED_SOURCE, after],
                      stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode:
        stop("dev is not descended from the reviewed perimeter-PASS source")
    changed = git("diff", "--name-only", APPROVED_SOURCE, after).splitlines()
    blocked = [path for path in changed if source_sensitive(path)]
    if blocked:
        stop("Wull-sensitive source changed; review before retesting: " + blocked[0])
    if SELF in changed:
        introductions = git("log", "--reverse", "--diff-filter=A", "--format=%H",
                            APPROVED_SOURCE + ".." + after, "--", SELF).splitlines()
        if len(introductions) != 1:
            stop("Diagnostic script introduction cannot be verified")
        original = subprocess.run(["git", "show", introductions[0] + ":" + SELF],
                                  stdout=subprocess.PIPE, check=True).stdout
        current = subprocess.run(["git", "show", after + ":" + SELF],
                                 stdout=subprocess.PIPE, check=True).stdout
        if original != current:
            stop("Qualification script was modified after its reviewed introduction")


def fetch():
    git("fetch", "--quiet", "origin",
        "refs/heads/dev:refs/remotes/origin/dev")
    return git("rev-parse", "refs/remotes/origin/dev")


def clean():
    return not git("status", "--porcelain=v1", "--untracked-files=all")


def run_check(name, argv, limit_seconds, env, log_dir):
    log_path = log_dir / (name + ".private.log")
    start = time.monotonic()
    clipped = False
    rc = 125
    with log_path.open("wb") as output:
        try:
            proc = subprocess.Popen(
                ["timeout", "--signal=TERM", "--kill-after=5s",
                 str(limit_seconds) + "s", *argv],
                stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                env=env, start_new_session=True
            )
            saved = 0
            deadline = time.monotonic() + limit_seconds + 12
            with selectors.DefaultSelector() as selector:
                selector.register(proc.stdout, selectors.EVENT_READ)
                while selector.get_map():
                    if time.monotonic() >= deadline:
                        try:
                            os.killpg(proc.pid, signal.SIGKILL)
                        except ProcessLookupError:
                            pass
                        clipped = True
                        rc = 124
                        break
                    if not selector.select(timeout=0.25):
                        continue
                    chunk = os.read(proc.stdout.fileno(), 65536)
                    if not chunk:
                        selector.unregister(proc.stdout)
                        break
                    room = max(0, MAX_LOG - saved)
                    if room:
                        output.write(chunk[:room])
                        saved += min(room, len(chunk))
                    if len(chunk) > room:
                        clipped = True
            proc.stdout.close()
            try:
                ended = proc.wait(timeout=5)
                if rc != 124:
                    rc = ended
            except subprocess.TimeoutExpired:
                os.killpg(proc.pid, signal.SIGKILL)
                proc.wait()
                rc = 124
                clipped = True
        except OSError:
            output.write(b"local_process_start_failure\n")
    result = {
        "check": name, "exit_code": rc,
        "status": "pass" if rc == 0 else ("timeout" if rc == 124 else "failed"),
        "duration_seconds": round(time.monotonic() - start, 2),
        "private_log_truncated": clipped,
    }
    print(name + ": " + result["status"] + " (exit " + str(rc) + ")", flush=True)
    return result


def main():
    os.umask(0o077)
    if Path.cwd().resolve() != Path(git("rev-parse", "--show-toplevel")).resolve():
        stop("Run from Hadalis repository root")
    if git("symbolic-ref", "--quiet", "--short", "HEAD") != "dev" or not clean():
        stop("A clean dev checkout is required")
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
        stop("Unexpected origin remote")
    if shutil.which("timeout") is None:
        stop("GNU timeout is required")

    remote = fetch()
    audit(remote)
    git("merge", "--ff-only", remote)
    if not clean():
        stop("Checkout changed during safe update")
    source = git("rev-parse", "HEAD")
    identifier = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ") + "-" + secrets.token_hex(4)
    state = Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state")))
    log_dir = state / "hadalis" / ("wull-qualification-" + identifier)
    log_dir.mkdir(mode=0o700, parents=True, exist_ok=False)
    print("EXACT_SOURCE_SHA:", source, flush=True)
    print("PRIVATE_LOG_DIRECTORY:", log_dir, flush=True)
    now = dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds")

    env = dict(os.environ)
    env["CARGO_TARGET_DIR"] = str(log_dir / "cargo-target")
    tests = [
        ("rust-unit", ["cargo", "test", "--locked", "--manifest-path",
                       "native/Cargo.toml", "-p", "inir-companiond"], 600),
        ("rust-release", ["cargo", "build", "--locked", "--release",
                          "--manifest-path", "native/Cargo.toml",
                          "-p", "inir-companiond"], 900),
    ]
    results = [run_check(name, argv, duration, env, log_dir)
               for name, argv, duration in tests]
    binary = log_dir / "cargo-target" / "release" / "inir-companiond"
    if results[1]["exit_code"] == 0 and binary.is_file():
        smoke_env = dict(env)
        smoke_env.update({
            "INIR_NATIVE_BACKEND": "rust", "INIR_NATIVE_STRICT": "1",
            "INIR_NATIVE_BIN_DIR": str(binary.parent),
        })
        results.append(run_check("dispatcher-version",
                                 ["bash", "scripts/native-dispatch", "companion",
                                  "--version"], 45, smoke_env, log_dir))
    else:
        results.append({
            "check": "dispatcher-version", "exit_code": None,
            "status": "skipped", "reason": "exact_source_release_build_not_ready",
        })
        print("dispatcher-version: skipped (release build unavailable)", flush=True)

    results.append(run_check("native-production-contract",
                             ["bash", "scripts/test-native-production-contract.sh"],
                             90, env, log_dir))
    # Separate packaging signal. The canonical validator also covers this
    # and many other tests; do not claim these independent results as live proof.
    results.append(run_check("package-metadata",
                             ["make", "-s", "test-package-metadata"], 120,
                             env, log_dir))
    canonical_env = dict(env)
    canonical_env["HADALIS_VALIDATION_LOG"] = str(
        log_dir / "maintainer-validation.private.log"
    )
    results.append(run_check("canonical-maintainer-validator",
                             ["bash", "scripts/validate-maintainer-local.sh",
                              "--current-repo"], 1800,
                             canonical_env, log_dir))
    # Trim validator's own diagnostic file; all raw evidence remains local.
    full_log = Path(canonical_env["HADALIS_VALIDATION_LOG"])
    if full_log.is_file() and full_log.stat().st_size > MAX_LOG:
        with full_log.open("rb") as stream:
            first = stream.read(262144)
            stream.seek(-524288, os.SEEK_END)
            last = stream.read()
        full_log.write_bytes(
            first + b"\n[PRIVATE LOG BOUNDED: middle omitted]\n" + last
        )
        for item in results:
            if item["check"] == "canonical-maintainer-validator":
                item["private_detailed_log_truncated"] = True
                break

    report = {
        "kind": "wull_manual_native_canonical_qualification",
        "source_sha": source,
        "started_utc": now,
        "finished_utc": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
        "status": "pass" if all(x["status"] == "pass" for x in results) else "failed",
        "existing_perimeter_receipt_sha": "642c676c2ce03ad5635c7fbbe3f278a1ce5da206",
        "checks": results,
        "live_host_acceptance": "not_run",
        "raw_logs": "private_local_only",
    }
    local = log_dir / "sanitized-summary.json"
    local.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("QUALIFICATION:", report["status"], flush=True)
    if git("rev-parse", "HEAD") != source or git("symbolic-ref", "--quiet", "--short", "HEAD") != "dev" or not clean():
        stop("Local repository changed; sanitized summary remains local")
    newer = fetch()
    audit(newer)
    git("merge", "--ff-only", newer)
    if not clean():
        stop("Unexpected local changes after tests; sanitized summary remains local")
    report["publication_parent_sha"] = git("rev-parse", "HEAD")
    report_path = Path("docs") / (
        "wull-manual-qualification-" + identifier + "-" + source[:12] + ".json"
    )
    if report_path.exists():
        stop("Report already exists")
    report_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    git("add", "--", str(report_path))
    if git("diff", "--cached", "--name-only") != str(report_path) or git("diff", "--name-only"):
        stop("Unexpected staged or local changes; refusing commit")
    if git("ls-files", "--others", "--exclude-standard"):
        stop("Unexpected untracked files; refusing commit")
    git("commit", "-m", "test(wull): publish sanitized native and canonical qualification", "--", str(report_path))
    # Never force-push or rebase a result onto changed history.
    git("push", "origin", "HEAD:refs/heads/dev")
    print("REPORT_PUBLISHED:", report_path, flush=True)
    print("REPORT_COMMIT:", git("rev-parse", "HEAD"), flush=True)


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, subprocess.CalledProcessError, OSError) as error:
        print("STOP:", error, file=sys.stderr)
        print("Any completed private diagnostics remain outside the repo.",
              file=sys.stderr)
        sys.exit(1)
