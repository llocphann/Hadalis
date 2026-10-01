#!/usr/bin/env python3
"""Manual bounded real-daemon Wull proof on Niri; never edits user configuration."""
import datetime as dt
import json
import os
from pathlib import Path
import secrets
import shutil
import signal
import subprocess
import sys
import time

BASE = "af2565174916c12a8360b2566ba755d00c050777"
SELF = "scripts/wull-manual-niri-proof.py"
REVIEWED_SOURCE = {
    "wullProof.qml",
    "modules/abyss/companion/AbyssCompanionProof.qml",
    "modules/abyss/companion/CompanionBridge.qml",
    "modules/abyss/companion/AbyssCompanion.qml",
    "modules/abyss/companion/WaterDropletBody.qml",
    "native/Cargo.toml",
    "native/Cargo.lock",
    "scripts/native-dispatch",
}
REMOTES = {
    "https://github.com/llocphann/Hadalis",
    "https://github.com/llocphann/Hadalis.git",
    "git@github.com:llocphann/Hadalis",
    "git@github.com:llocphann/Hadalis.git",
    "ssh://git@github.com/llocphann/Hadalis",
    "ssh://git@github.com/llocphann/Hadalis.git",
}
MAX_PRIVATE_LOG_BYTES = 1048576
WINDOW_TITLE = "Wull procedural attachment proof [present]"


def git(*args):
    process = subprocess.run(
        ["git", *args], capture_output=True, text=True, timeout=30
    )
    if process.returncode:
        raise RuntimeError("Git operation failed: " + " ".join(args))
    return process.stdout.strip()


def clean():
    return git("status", "--porcelain=v1", "--untracked-files=all") == ""


def fetch():
    git("fetch", "--quiet", "origin", "refs/heads/dev:refs/remotes/origin/dev")
    return git("rev-parse", "refs/remotes/origin/dev")


def audit(target):
    if subprocess.run(
        ["git", "merge-base", "--is-ancestor", BASE, target],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    ).returncode:
        raise RuntimeError("Remote does not descend from the reviewed Wull source")
    modified = set(git("diff", "--name-only", BASE, target).splitlines())
    if modified & REVIEWED_SOURCE or any(
        name.startswith("native/inir-companiond/") for name in modified
    ):
        raise RuntimeError("Reviewed Wull renderer/daemon source changed")
    if SELF in modified:
        revisions = git(
            "log", "--format=%H", BASE + ".." + target,
            "--", SELF
        ).splitlines()
        if len(revisions) != 1:
            raise RuntimeError("Live proof script changed beyond its reviewed revision")
        original = subprocess.run(
            ["git", "show", revisions[0] + ":" + SELF],
            check=True, capture_output=True, timeout=10
        ).stdout
        latest = subprocess.run(
            ["git", "show", target + ":" + SELF],
            check=True, capture_output=True, timeout=10
        ).stdout
        if original != latest:
            raise RuntimeError("Live proof script differs from its reviewed revision")


def truncate_private_log(path):
    if path.is_file() and path.stat().st_size > MAX_PRIVATE_LOG_BYTES:
        with path.open("rb") as stream:
            first = stream.read(262144)
            stream.seek(-524288, os.SEEK_END)
            last = stream.read()
        path.write_bytes(first + b"\n[PRIVATE LOG MIDDLE OMITTED]\n" + last)


def windows(niri):
    result = subprocess.run(
        [niri, "msg", "-j", "windows"],
        capture_output=True, text=True, timeout=4
    )
    if result.returncode:
        raise RuntimeError("Niri window API not available in this session")
    data = json.loads(result.stdout)
    if not isinstance(data, list):
        raise RuntimeError("Unexpected Niri window response")
    return {
        record["id"]: record.get("title", "")
        for record in data
        if isinstance(record, dict)
        and isinstance(record.get("id"), int)
        and isinstance(record.get("title", ""), str)
    }


def owned_pids(binary):
    """Inspect only executable identity; do not capture other process arguments."""
    target = str(binary.resolve())
    found = []
    for proc in Path("/proc").iterdir():
        if not proc.name.isdigit():
            continue
        try:
            if os.readlink(proc / "exe") == target:
                found.append(int(proc.name))
        except (OSError, PermissionError):
            pass
    return found


def rss_kib(pid):
    try:
        for row in (Path("/proc") / str(pid) / "status").read_text().splitlines():
            if row.startswith("VmRSS:"):
                return int(row.split()[1])
    except (OSError, ValueError, IndexError):
        pass
    return None


def stop_owned_process_group(proc, binary):
    if proc is not None and proc.poll() is None:
        try:
            os.killpg(proc.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        try:
            proc.wait(timeout=4)
        except subprocess.TimeoutExpired:
            try:
                os.killpg(proc.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            proc.wait(timeout=3)
    # A Qt-spawned child may use a separate process group. This executable
    # lives in this run's newly created private Cargo target directory.
    for pid in owned_pids(binary):
        try:
            os.kill(pid, signal.SIGTERM)
        except ProcessLookupError:
            pass


def proof(qs, niri, folder):
    result = {
        "check": "bounded_real_daemon_standalone_niri_proof",
        "status": "failed",
        "reason": None,
        "rust_release_exit_code": None,
        "niri_window_mapped": False,
        "single_owned_daemon": False,
        "own_daemon_stopped": False,
        "own_window_unmapped": False,
        "max_sampled_daemon_rss_kib": None,
        "live_input_mask_acceptance": "not_run",
        "live_production_host_acceptance": "not_run",
        "visual_acceptance": "not_run",
    }
    try:
        prior = windows(niri)
    except (OSError, ValueError, subprocess.TimeoutExpired, RuntimeError):
        result["status"] = "inconclusive"
        result["reason"] = "niri_window_api_unavailable"
        return result

    private_target = folder / "cargo-target"
    binary = private_target / "release" / "inir-companiond"
    build_env = dict(os.environ)
    build_env["CARGO_TARGET_DIR"] = str(private_target)
    build_log = folder / "cargo-build.private.log"
    with build_log.open("wb") as output:
        try:
            build = subprocess.run(
                ["cargo", "build", "--locked", "--release", "--manifest-path",
                 "native/Cargo.toml", "-p", "inir-companiond"],
                stdout=output, stderr=subprocess.STDOUT,
                env=build_env, timeout=900
            )
            result["rust_release_exit_code"] = build.returncode
        except subprocess.TimeoutExpired:
            result["rust_release_exit_code"] = 124
    truncate_private_log(build_log)
    if result["rust_release_exit_code"] != 0 or not binary.is_file():
        result["reason"] = "exact_sha_release_build_failed"
        return result
    if owned_pids(binary):
        result["reason"] = "private_binary_already_running"
        return result

    isolated = folder / "xdg"
    for name in ("config", "data", "cache", "state"):
        (isolated / name).mkdir(parents=True)
    env = dict(os.environ)
    env.update({
        "INIR_COMPANIOND": str(binary),
        "QS_NO_RELOAD_POPUP": "1",
        "QT_QPA_PLATFORM": "wayland",
        "XDG_CONFIG_HOME": str(isolated / "config"),
        "XDG_DATA_HOME": str(isolated / "data"),
        "XDG_CACHE_HOME": str(isolated / "cache"),
        "XDG_STATE_HOME": str(isolated / "state"),
    })
    log = folder / "quickshell.private.log"
    proc = None
    seen_window = None
    max_rss = 0
    steady_samples = 0
    started = time.monotonic()
    try:
        with log.open("wb") as output:
            proc = subprocess.Popen(
                [qs, "-n", "-p", "wullProof.qml"],
                stdout=output, stderr=subprocess.STDOUT,
                env=env, start_new_session=True
            )
            while time.monotonic() - started < 16:
                if proc.poll() is not None:
                    result["reason"] = "quickshell_exited_before_proof"
                    break
                try:
                    current = windows(niri)
                except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired):
                    result["reason"] = "niri_window_api_lost"
                    break
                new_titles = {
                    identity: title for identity, title in current.items()
                    if identity not in prior
                }
                for identity, title in new_titles.items():
                    if title == WINDOW_TITLE:
                        seen_window = identity
                        result["niri_window_mapped"] = True
                        break
                if seen_window is not None:
                    current_pids = owned_pids(binary)
                    if len(current_pids) == 1:
                        steady_samples += 1
                        reading = rss_kib(current_pids[0])
                        if reading is not None:
                            max_rss = max(reading, max_rss)
                        if steady_samples >= 3:
                            result["single_owned_daemon"] = True
                            result["reason"] = None
                            break
                    elif len(current_pids) > 1:
                        result["reason"] = "duplicate_owned_daemon"
                        break
                    else:
                        steady_samples = 0
                time.sleep(0.4)
            if not result["niri_window_mapped"] and result["reason"] is None:
                result["reason"] = "standalone_window_not_mapped_in_time"
            elif not result["single_owned_daemon"] and result["reason"] is None:
                result["reason"] = "single_daemon_not_proven"
    except OSError:
        result["reason"] = "quickshell_launch_failed"
    finally:
        stop_owned_process_group(proc, binary)
        truncate_private_log(log)

    if max_rss:
        result["max_sampled_daemon_rss_kib"] = max_rss
    until = time.monotonic() + 6
    while time.monotonic() < until:
        result["own_daemon_stopped"] = len(owned_pids(binary)) == 0
        try:
            after = windows(niri)
            result["own_window_unmapped"] = (
                seen_window is not None and seen_window not in after
            )
        except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired):
            result["own_window_unmapped"] = False
        if result["own_daemon_stopped"] and (
            seen_window is None or result["own_window_unmapped"]
        ):
            break
        time.sleep(0.3)
    if not result["own_daemon_stopped"]:
        result["reason"] = "private_daemon_cleanup_incomplete"
    if all(result[key] for key in (
        "niri_window_mapped", "single_owned_daemon",
        "own_daemon_stopped", "own_window_unmapped"
    )):
        result["status"] = "pass"
        result["reason"] = None
    return result


def publish(report, report_path):
    """Only rebase a single not-yet-shared report commit after remote audit."""
    for attempt in range(4):
        remote_result = subprocess.run(
            ["git", "push", "origin", "HEAD:refs/heads/dev"],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
            timeout=45
        )
        if remote_result.returncode == 0:
            return
        if attempt == 3:
            raise RuntimeError("Report push rejected; the report remains local")
        if not clean() or git("diff-tree", "--no-commit-id", "--name-only",
                              "-r", "HEAD") != str(report_path):
            raise RuntimeError("Local unpublished commit is not solely this report")
        old_parent = git("rev-parse", "HEAD^")
        new_remote = fetch()
        audit(new_remote)
        if subprocess.run(
            ["git", "merge-base", "--is-ancestor", "HEAD", new_remote],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
        ).returncode == 0:
            return
        if subprocess.run(
            ["git", "merge-base", "--is-ancestor", old_parent, new_remote],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
        ).returncode:
            raise RuntimeError("Unrelated remote history; no report publication")
        git("rebase", "--onto", new_remote, old_parent)
        if not clean() or git("diff-tree", "--no-commit-id", "--name-only",
                              "-r", "HEAD") != str(report_path):
            raise RuntimeError("The rebased report commit was unexpectedly changed")
        report["publication_parent_sha"] = git("rev-parse", "HEAD^")
        report_path.write_text(json.dumps(report, indent=2) + "\n")
        git("add", "--", str(report_path))
        if git("diff", "--cached", "--name-only") != str(report_path):
            raise RuntimeError("Unexpected staged changes during publication")
        git("commit", "--amend", "--no-edit")


def main():
    os.umask(0o077)
    if sys.argv[1:]:
        raise RuntimeError("Usage: python3 scripts/wull-manual-niri-proof.py")
    if Path.cwd().resolve() != Path(git("rev-parse", "--show-toplevel")).resolve():
        raise RuntimeError("Run from repository root")
    if git("symbolic-ref", "--quiet", "--short", "HEAD") != "dev" or not clean():
        raise RuntimeError("A clean dev checkout is required")
    push_urls = git("remote", "get-url", "--push", "--all", "origin").splitlines()
    if git("remote", "get-url", "origin") not in REMOTES or (
        len(push_urls) != 1 or push_urls[0] not in REMOTES
    ):
        raise RuntimeError("Unexpected origin URL")
    remote = fetch()
    audit(remote)
    git("merge", "--ff-only", remote)
    if not clean():
        raise RuntimeError("Checkout became dirty")
    source = git("rev-parse", "HEAD")
    identifier = dt.datetime.now(dt.timezone.utc).strftime(
        "%Y%m%dT%H%M%SZ"
    ) + "-" + secrets.token_hex(4)
    state = Path(os.environ.get(
        "XDG_STATE_HOME", str(Path.home() / ".local/state")
    )).resolve()
    private = state / "hadalis" / ("wull-niri-proof-" + identifier)
    private.mkdir(parents=True, exist_ok=False, mode=0o700)
    print("EXACT_SOURCE_SHA:", source, flush=True)
    print("PRIVATE_LOG_DIRECTORY:", private, flush=True)

    qs = shutil.which("qs") or shutil.which("quickshell")
    niri = shutil.which("niri")
    cargo = shutil.which("cargo")
    if qs is None or niri is None or cargo is None:
        diagnostic = {
            "check": "real_daemon_niri_preflight", "status": "inconclusive",
            "reason": "required_local_tool_unavailable",
        }
    else:
        diagnostic = proof(qs, niri, private)
    status = diagnostic["status"]
    report = {
        "kind": "wull_manual_real_daemon_niri_proof",
        "source_sha": source,
        "scope": "standalone_wullProof_only",
        "status": status,
        "test": diagnostic,
        "production_host_acceptance": "not_run",
        "canonical_validation": "not_run",
        "live_visual_acceptance": "not_run",
        "multi_output_and_input_mask_acceptance": "not_run",
        "private_logs": "local_only",
    }
    (private / "sanitized-summary.json").write_text(
        json.dumps(report, indent=2) + "\n", encoding="utf-8"
    )
    print("NIRI_PROOF:", status, flush=True)
    if git("rev-parse", "HEAD") != source or not clean():
        raise RuntimeError("Local checkout changed; proof retained privately")
    updated = fetch()
    audit(updated)
    git("merge", "--ff-only", updated)
    if not clean():
        raise RuntimeError("Unexpected local changes before publication")
    report["publication_parent_sha"] = git("rev-parse", "HEAD")
    path = Path("docs") / ("wull-niri-proof-" + identifier
                           + "-" + source[:12] + ".json")
    if path.exists():
        raise RuntimeError("Refusing to overwrite a proof report")
    path.write_text(json.dumps(report, indent=2) + "\n")
    git("add", "--", str(path))
    if git("diff", "--cached", "--name-only") != str(path) or (
        git("diff", "--name-only") or
        git("ls-files", "--others", "--exclude-standard")
    ):
        raise RuntimeError("Unexpected changes before report commit")
    git("commit", "-m", "test(wull): publish bounded real-daemon Niri proof",
        "--", str(path))
    publish(report, path)
    print("REPORT_PUBLISHED:", path, flush=True)
    print("REPORT_COMMIT:", git("rev-parse", "HEAD"), flush=True)


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError, ValueError, subprocess.TimeoutExpired,
            subprocess.CalledProcessError) as error:
        print("STOP:", error, file=sys.stderr)
        print("If already run, private evidence remains on this machine.",
              file=sys.stderr)
        sys.exit(1)
