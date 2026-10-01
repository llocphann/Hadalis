#!/usr/bin/env python3
"""Explicit nested-only REAL Wull pointer acceptance coordinator.

Runs inert-source-reviewed test child ONLY on a verified new owned nested
Niri socket. A missing native wdotool/protocol is INCONCLUSIVE, never a
permission fallback to the active desktop. Publishes sanitized evidence only.
"""
import datetime as dt
import json
import os
from pathlib import Path
import runpy
import secrets
import shutil
import signal
import socket
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
BASE = "f484789543a223c2972c99da8928c2064f9fbc95"
SELF = "scripts/wull-manual-nested-pointer.py"
INITIAL_SELF_BLOB = "1f86887e515045c65e33336f3df8ca80a0cc3e4c"
CHILD = "scripts/wull-manual-pointer-child.py"
NESTED_HELPER = "scripts/wull-manual-nested-niri.py"
SAFE_REMOTES = {
    "https://github.com/llocphann/Hadalis",
    "https://github.com/llocphann/Hadalis.git",
    "git@github.com:llocphann/Hadalis",
    "git@github.com:llocphann/Hadalis.git",
    "ssh://git@github.com/llocphann/Hadalis",
    "ssh://git@github.com:llocphann/Hadalis.git",
}
# SHA-pinned implementation and real production interfaces. A changed
# source dependency must be re-reviewed, never silently accepted as PASS.
REVIEWED = {
    CHILD: "b441a172c571ec434980c054389b40dac415c824",
    NESTED_HELPER: "7edf8328df1f9704f1331fbe1a5e84e659cd360a",
    "scripts/wull-fixtures/production-layer/shell.qml":
        "e16b6dcada26a27fd71cc670e30c55135401bcef",
    "scripts/wull-fixtures/pointer-underlay/shell.qml":
        "490a50b0ecd92a094840583443cd73fa8b746683",
    "scripts/wull-fixtures/pointer-underlay/companion-relay.py":
        "7e450db1db23e3c250859b0271a655d6325f0bc8",
    "scripts/wull-pointer-targets.py":
        "af3c0e1fdf090fae105d851d75aeed1954775915",
    "modules/abyss/AbyssPerimeter.qml":
        "a3cd2a7bfbdf32dac2c7e42057a1dfaaeea214ac",
    "modules/abyss/companion/AbyssCompanion.qml":
        "b5b01835a282458eba0d0268396ae2c350d919d2",
    "modules/abyss/companion/WaterDropletBody.qml":
        "fc5b1c227026786ab553685bc170daff74e82517",
    "modules/abyss/companion/CompanionBridge.qml":
        "93c8d99497988f86660547773e8c30d90ac4bb66",
    "modules/abyss/companion/WullHostPolicy.js":
        "3503c25f025648c963ef00ecd871a7a4c09914b7",
    "defaults/config.json": "e10d98c0f26d3e47c51cb8452bcd0d2cea735501",
}
MAX_LOG = 1048576
HELPERS = runpy.run_path(str(ROOT / NESTED_HELPER),
                         run_name="wull_nested_pointer_import_only")
startup_identity = HELPERS["startup_identity"]
inventory = HELPERS["inventory"]
alive_ipc = HELPERS["alive_ipc"]
stop_owned = HELPERS["stop_owned"]
trim_log = HELPERS["trim_log"]


def git(*args):
    item = subprocess.run(["git", *args], capture_output=True, text=True,
                          timeout=45)
    if item.returncode:
        raise RuntimeError("git_command_failed")
    return item.stdout.strip()


def clean():
    return git("status", "--porcelain=v1", "--untracked-files=all") == ""


def fetch():
    git("fetch", "--quiet", "origin",
        "refs/heads/dev:refs/remotes/origin/dev")
    return git("rev-parse", "refs/remotes/origin/dev")


def audit(source):
    ancestor = subprocess.run(["git", "merge-base", "--is-ancestor",
                               BASE, source], capture_output=True, timeout=10)
    if ancestor.returncode:
        raise RuntimeError("reviewed_pointer_baseline_not_ancestor")
    for path, blob in REVIEWED.items():
        if git("rev-parse", source + ":" + path) != blob:
            raise RuntimeError("pointer_dependency_changed_after_review")
    revision = git("log", "--format=%H", BASE + ".." + source,
                   "--", SELF).splitlines()
    if (len(revision) != 9
            or git("rev-parse", revision[-1] + ":" + SELF)
            != INITIAL_SELF_BLOB
            or git("rev-parse", revision[0] + ":" + SELF)
            != git("rev-parse", source + ":" + SELF)):
        raise RuntimeError("unreviewed_pointer_coordinator_revision")
    # A Rust dependency change would invalidate the pre-run source review.
    diffs = git("diff", "--name-only", BASE, source).splitlines()
    if any(part.startswith("native/inir-companiond/") or part in (
            "native/Cargo.toml", "native/Cargo.lock", "AGENTS.md",
            "scripts/native-dispatch") for part in diffs):
        raise RuntimeError("native_or_agent_dependency_changed_after_review")


def native_layers(niri, socket_path):
    env = dict(os.environ, NIRI_SOCKET=str(socket_path))
    done = subprocess.run([niri, "msg", "-j", "layers"], env=env,
                          capture_output=True, timeout=5)
    if done.returncode:
        return None
    try:
        obj = json.loads(done.stdout)
        if isinstance(obj, dict) and "Ok" in obj:
            obj = obj["Ok"]
        if isinstance(obj, dict):
            obj = obj.get("Layers", obj.get("layers"))
        return obj if isinstance(obj, list) else None
    except (ValueError, AttributeError):
        return None


def private_strays(private):
    """Enumerate only same-UID processes with this random private path in argv."""
    found = []
    stem = str(private.resolve()).encode()
    for entry in Path("/proc").iterdir():
        if not entry.name.isdigit():
            continue
        try:
            if entry.stat().st_uid != os.getuid():
                continue
            tokens = (entry / "cmdline").read_bytes().split(bytes([0]))
            if any(stem in token for token in tokens):
                found.append(int(entry.name))
        except (OSError, PermissionError):
            continue
    return [pid for pid in found if pid != os.getpid()]


def stop_private_strays(private, force=False):
    """Only touch verified owned private descendants; no group-ID guessing."""
    for pid in private_strays(private):
        try:
            os.kill(pid, signal.SIGKILL if force else signal.SIGTERM)
        except ProcessLookupError:
            pass


def stop_owned_child_group(child):
    """Terminate the owned nested child AND its in-group Cargo/input children.

    The Popen child is started with start_new_session=True. Never signal its
    numeric PGID after that group leader exited: the ID might be reused.
    Independent Quickshell sessions use their own groups and are separately
    handled by the private-path cleanup below.
    """
    if child is None or child.poll() is not None:
        return
    try:
        os.killpg(child.pid, signal.SIGTERM)
    except ProcessLookupError:
        return
    try:
        child.wait(timeout=12)
    except subprocess.TimeoutExpired:
        if child.poll() is None:
            try:
                os.killpg(child.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            child.wait(timeout=4)


def run_nested(niri, private, host_display, host_ipc, host_outputs):
    data = {
        "nested_started": False, "distinct_nested_endpoints": False,
        "nested_one_output": False, "nested_empty_before_test": False,
        "child_exit_code": None, "child_result": "not_run",
        "child_reason": None, "child_checks": [],
        "nested_stopped": False, "host_outputs_unchanged": False,
        "owned_private_strays": False,
        "forced_private_cleanup": False
    }
    private.mkdir(mode=0o700, parents=True)
    config = private / "nested.kdl"
    config.write_text("", encoding="utf-8")
    nested_log = private / "nested-niri.private.log"
    child_log = private / "pointer-child.private.log"
    env = dict(os.environ)
    env.pop("NIRI_SOCKET", None)
    env.update({"NIRI_CONFIG": str(config),
                "XDG_CONFIG_HOME": str(private / "config"),
                "XDG_DATA_HOME": str(private / "data"),
                "XDG_CACHE_HOME": str(private / "cache"),
                "XDG_STATE_HOME": str(private / "state"),
                "WAYLAND_DISPLAY": host_display})
    for item in ("config", "data", "cache", "state"):
        (private / item).mkdir()
    nested = None
    ipc = None
    child = None
    try:
        with nested_log.open("wb") as log:
            nested = subprocess.Popen([niri], env=env,
                                      stdin=subprocess.DEVNULL,
                                      stdout=log, stderr=subprocess.STDOUT,
                                      start_new_session=True)
        deadline = time.monotonic() + 23
        display = None
        while time.monotonic() < deadline:
            if nested.poll() is not None:
                break
            log_text = nested_log.read_text(encoding="utf-8",
                                            errors="replace")[:MAX_LOG]
            candidate_display, candidate_ipc = startup_identity(log_text)
            if (candidate_display and candidate_ipc
                    and candidate_display != host_display
                    and candidate_ipc != host_ipc):
                runtime = Path(os.environ["XDG_RUNTIME_DIR"]).resolve()
                candidate = Path(candidate_ipc).resolve()
                if (candidate.parent != runtime or not candidate.is_socket()
                        or not (runtime / candidate_display).is_socket()):
                    break
                count = inventory(niri, candidate_ipc)
                if count == 1:
                    display, ipc = candidate_display, candidate_ipc
                    data["nested_started"] = True
                    data["distinct_nested_endpoints"] = True
                    data["nested_one_output"] = True
                    break
            time.sleep(.25)
        if not data["nested_started"]:
            data["child_reason"] = "owned_nested_startup_not_verified"
            return data
        layers = native_layers(niri, ipc)
        if layers is None:
            data["child_reason"] = "nested_layer_inventory_missing"
            return data
        if any(isinstance(x, dict) and x.get("namespace") in (
                "hadalis:abyss-perimeter", "hadalis:wull-pointer-underlay")
               for x in layers):
            data["child_reason"] = "nested_layer_namespace_already_claimed"
            return data
        data["nested_empty_before_test"] = True
        child_env = dict(os.environ)
        child_env.update({
            "NIRI_SOCKET": ipc, "WAYLAND_DISPLAY": display,
            "WULL_PARENT_NIRI_SOCKET": host_ipc,
            "WULL_PARENT_WAYLAND_DISPLAY": host_display,
            "WULL_PRIVATE_POINTER_NESTED_SOCKET": ipc,
            "WULL_PRIVATE_POINTER_CHILD": "owned-nested",
            "WULL_PRIVATE_POINTER_ROOT": str(private / "child"),
        })
        (private / "child").mkdir(mode=0o700)
        with child_log.open("wb") as output:
            child = subprocess.Popen(
                [sys.executable, str(ROOT / CHILD), "--nested-child"],
                env=child_env, stdin=subprocess.DEVNULL, stdout=output,
                stderr=subprocess.STDOUT, start_new_session=True)
            try:
                data["child_exit_code"] = child.wait(timeout=1080)
            except subprocess.TimeoutExpired:
                data["child_exit_code"] = 124
                stop_owned_child_group(child)
        trim_log(child_log)
        summary = private / "child" / "pointer-child.private-summary.json"
        if summary.is_file() and summary.stat().st_size <= 65536:
            try:
                raw = json.loads(summary.read_text())
                data["child_result"] = raw["status"]
                data["child_reason"] = raw.get("reason")
                data["child_checks"] = raw.get("checks", [])
                for item in ("nested_verified", "underlay_unmapped",
                             "production_unmapped", "private_daemon_stopped",
                             "real_rust_binary_built", "whole_host_mask_changed",
                             "injection_backend"):
                    data[item] = raw.get(item)
            except (ValueError, KeyError, TypeError):
                data["child_reason"] = "child_summary_unreadable"
        elif data["child_exit_code"] == 124:
            data["child_reason"] = "nested_pointer_child_timeout"
        else:
            data["child_reason"] = "nested_pointer_child_no_receipt"
        return data
    finally:
        stop_owned_child_group(child)
        stop_owned(nested)
        trim_log(nested_log)
        trim_log(child_log)
        child_dir = private / "child"
        stop_private_strays(child_dir)
        stray_deadline = time.monotonic() + 5
        while private_strays(child_dir) and time.monotonic() < stray_deadline:
            time.sleep(.20)
        if private_strays(child_dir):
            data["forced_private_cleanup"] = True
            stop_private_strays(child_dir, force=True)
            time.sleep(.4)
        if ipc:
            deadline = time.monotonic() + 5
            while time.monotonic() < deadline and alive_ipc(ipc):
                time.sleep(.25)
            data["nested_stopped"] = not alive_ipc(ipc)
        else:
            data["nested_stopped"] = nested is None or nested.poll() is not None
        data["host_outputs_unchanged"] = inventory(niri, host_ipc) == host_outputs
        data["owned_private_strays"] = bool(private_strays(private / "child"))


def publish(report, path):
    for attempt in range(4):
        done = subprocess.run(["git", "push", "origin", "HEAD:refs/heads/dev"],
                              capture_output=True, timeout=50)
        if done.returncode == 0:
            return
        if attempt == 3:
            raise RuntimeError("pointer_report_push_refused_kept_local")
        if (not clean()
                or git("diff-tree", "--no-commit-id", "--name-only",
                       "-r", "HEAD") != str(path)):
            raise RuntimeError("cannot_retry_nonreceipt_commit")
        parent = git("rev-parse", "HEAD^")
        remote = fetch()
        audit(remote)
        if subprocess.run(["git", "merge-base", "--is-ancestor",
                           parent, remote], capture_output=True,
                          timeout=10).returncode:
            raise RuntimeError("remote_history_diverged_kept_local")
        git("rebase", "--onto", remote, parent)  # own unpublished receipt ONLY
        if (not clean()
                or git("diff-tree", "--no-commit-id", "--name-only",
                       "-r", "HEAD") != str(path)):
            raise RuntimeError("own_receipt_retry_integrity_failed")
        report["publication_parent_sha"] = git("rev-parse", "HEAD^")
        path.write_text(json.dumps(report, indent=2) + "\n")
        git("add", "--", str(path))
        if git("diff", "--cached", "--name-only") != str(path):
            raise RuntimeError("unreviewed_staged_paths_during_retry")
        git("commit", "--amend", "--no-edit")


def main():
    if sys.argv[1:] != ["--acknowledge-nested-pointer"]:
        raise RuntimeError("explicit_nested_pointer_opt_in_required")
    os.umask(0o077)
    if (Path.cwd().resolve() != ROOT
            or git("symbolic-ref", "--short", "HEAD") != "dev"
            or not clean()):
        raise RuntimeError("clean_dev_repository_root_required")
    origin = git("remote", "get-url", "origin")
    push_urls = git("remote", "get-url", "--push", "--all", "origin").splitlines()
    if origin not in SAFE_REMOTES or len(push_urls) != 1 or (
            push_urls[0] not in SAFE_REMOTES):
        raise RuntimeError("unexpected_remote_origin")
    remote = fetch()
    audit(remote)
    git("merge", "--ff-only", remote)
    if not clean():
        raise RuntimeError("unexpected_checkout_change")
    source = git("rev-parse", "HEAD")
    identifier = dt.datetime.now(dt.timezone.utc).strftime(
        "%Y%m%dT%H%M%SZ") + "-" + secrets.token_hex(4)
    state = Path(os.environ.get("XDG_STATE_HOME",
                str(Path.home() / ".local/state"))).resolve()
    private = state / "hadalis" / ("wull-pointer-" + identifier)
    if private == ROOT or ROOT in private.parents:
        raise RuntimeError("private_diagnostics_inside_repository")
    private.mkdir(parents=True, exist_ok=False, mode=0o700)
    print("EXACT_SOURCE_SHA:", source, flush=True)
    niri = shutil.which("niri")
    desktop = os.environ.get("WAYLAND_DISPLAY", "")
    host_ipc = os.environ.get("NIRI_SOCKET", "")
    runtime = os.environ.get("XDG_RUNTIME_DIR", "")
    reason = None
    observations = None
    if not niri or not desktop or not host_ipc or not runtime:
        reason = "missing_host_niri_wayland_environment"
    elif not Path(host_ipc).is_socket() or not (
            Path(runtime) / desktop).is_socket():
        reason = "host_wayland_or_niri_socket_missing"
    elif not (shutil.which("wdotool") or shutil.which("wlrctl")):
        reason = "native_pointer_cli_missing_no_input_injected"
    elif not all(shutil.which(x) for x in ("cargo", "dbus-run-session")) or not (
            shutil.which("qs") or shutil.which("quickshell")):
        reason = "nested_pointer_dependencies_unavailable"
    else:
        host_outputs = inventory(niri, host_ipc)
        if host_outputs is None or host_outputs <= 0:
            reason = "host_niri_inventory_unavailable"
        else:
            observations = run_nested(niri, private / "nested", desktop,
                                      host_ipc, host_outputs)
    if reason:
        status = "inconclusive"
    elif observations["child_result"] == "pass" and all((
            observations["nested_started"],
            observations["distinct_nested_endpoints"],
            observations["nested_one_output"],
            observations["nested_empty_before_test"],
            observations["child_exit_code"] == 0,
            observations["nested_stopped"],
            observations["host_outputs_unchanged"],
            not observations["owned_private_strays"],
            observations.get("underlay_unmapped"),
            observations.get("production_unmapped"),
            observations.get("private_daemon_stopped"),
            observations.get("real_rust_binary_built"),
            observations.get("whole_host_mask_changed") is False
    )):
        status = "pass"
    elif observations["child_result"] == "failed" or not all((
            observations["nested_stopped"],
            observations["host_outputs_unchanged"],
            not observations["owned_private_strays"],
    )):
        status = "failed"
    else:
        status = "inconclusive"
    receipt = {
        "kind": "wull_manual_real_nested_pointer_acceptance",
        "source_sha": source, "status": status,
        "preflight_reason": reason,
        "scope": "owned_single_output_nested_niri_real_production_pointer",
        "observation": observations,
        "native_pointer_backend": (
            observations.get("injection_backend", "unavailable_or_unverified")
            if observations else "unavailable_or_unverified"),
        "host_user_config_changed": False,
        "production_mask_changed": False,
        "visual_and_multioutput_acceptance": "not_run",
        "canonical_validation": "not_run",
        "raw_coordinates_screenshots_logs": "private_local_only",
    }
    (private / "sanitized-summary.json").write_text(
        json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print("WULL_REAL_POINTER_RESULT:", status, flush=True)
    print("WULL_REAL_POINTER_REASON:",
          reason or observations.get("child_reason"), flush=True)
    if not clean() or git("rev-parse", "HEAD") != source:
        raise RuntimeError("source_changed_evidence_remains_local")
    newer = fetch()
    audit(newer)
    if subprocess.run(["git", "merge-base", "--is-ancestor",
                       source, newer], capture_output=True, timeout=10).returncode:
        raise RuntimeError("remote_changed_non_fast_forward")
    git("merge", "--ff-only", newer)
    if not clean():
        raise RuntimeError("dirty_publication_checkout")
    receipt["publication_parent_sha"] = git("rev-parse", "HEAD")
    path = Path("docs") / ("wull-pointer-acceptance-" + identifier
                           + "-" + source[:12] + ".json")
    if path.exists():
        raise RuntimeError("refusing_to_overwrite_pointer_receipt")
    path.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    git("add", "--", str(path))
    if (git("diff", "--cached", "--name-only") != str(path)
            or git("diff", "--name-only")
            or git("ls-files", "--others", "--exclude-standard")):
        raise RuntimeError("unexpected_report_publication_changes")
    git("commit", "-m", "test(wull): publish isolated real pointer acceptance",
        "--", str(path))
    publish(receipt, path)
    print("REPORT_PUBLISHED:", path, flush=True)


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, ValueError, OSError, subprocess.TimeoutExpired) as e:
        print("STOP:", str(e).split(":")[0], file=sys.stderr)
        print("Private diagnostics remain local if created.", file=sys.stderr)
        sys.exit(1)
