#!/usr/bin/env python3
"""Explicitly opted-in Niri-in-Niri Wull production test coordinator.

Starts one owned nested Niri as an ordinary Wayland window; the reviewed
production-layer probe runs against ONLY its socket. Host shell is untouched.
All unfiltered compositor/child logs remain private on the local machine.
"""
import datetime as dt
import json
import os
from pathlib import Path
import re
import secrets
import shutil
import signal
import socket
import subprocess
import sys
import time

BASE = "ef4316953e2254104741a4f9bd0b780e4c9a7836"
SELF = "scripts/wull-manual-nested-niri.py"
CONTRACT = "scripts/test-wull-nested-niri-contract.py"
INNER = "scripts/wull-manual-production-layer.py"
INNER_BLOB = "b6bb9a390042ef90c88478d495cd0f3e6e1ae832"
FIXTURE = "scripts/wull-fixtures/production-layer/shell.qml"
FIXTURE_BLOB = "e16b6dcada26a27fd71cc670e30c55135401bcef"
INITIAL_SELF_BLOB = "acbea356a22daed2b92f239db326b964172ede70"
ORIGINS = {
    "https://github.com/llocphann/Hadalis",
    "https://github.com/llocphann/Hadalis.git",
    "git@github.com:llocphann/Hadalis",
    "git@github.com:llocphann/Hadalis.git",
    "ssh://git@github.com/llocphann/Hadalis",
    "ssh://git@github.com/llocphann/Hadalis.git",
}
MAX_LOG = 1048576


def git(*args):
    done = subprocess.run(["git", *args], capture_output=True, text=True,
                          timeout=40)
    if done.returncode:
        raise RuntimeError("Git operation failed: " + " ".join(args))
    return done.stdout.strip()


def clean():
    return git("status", "--porcelain=v1", "--untracked-files=all") == ""


def fetch():
    git("fetch", "--quiet", "origin", "refs/heads/dev:refs/remotes/origin/dev")
    return git("rev-parse", "refs/remotes/origin/dev")


def audit(target):
    if subprocess.run(["git", "merge-base", "--is-ancestor", BASE, target],
                      stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                      timeout=10).returncode:
        raise RuntimeError("Remote does not descend from reviewed nested baseline")
    if git("rev-parse", target + ":" + INNER) != INNER_BLOB:
        raise RuntimeError("Reviewed production-layer child changed")
    if git("rev-parse", target + ":" + FIXTURE) != FIXTURE_BLOB:
        raise RuntimeError("Reviewed production-layer QML changed")
    if git("rev-parse", BASE + ":" + SELF) != INITIAL_SELF_BLOB:
        raise RuntimeError("Reviewed nested observer baseline source changed")
    for path in (SELF, CONTRACT):
        changes = git("log", "--format=%H", BASE + ".." + target,
                      "--", path).splitlines()
        expected = 2 if path == SELF else 0
        if len(changes) != expected:
            raise RuntimeError("Nested observer changed outside reviewed revisions")
        if expected and (
            git("rev-parse", changes[0] + ":" + path)
            != git("rev-parse", target + ":" + path)
        ):
            raise RuntimeError("Nested observer differs from reviewed revision")


def inventory(binary, target):
    env = dict(os.environ)
    env["NIRI_SOCKET"] = str(target)
    done = subprocess.run([binary, "msg", "-j", "outputs"], env=env,
                          capture_output=True, text=True, timeout=5)
    if done.returncode:
        return None
    try:
        body = json.loads(done.stdout)
        if isinstance(body, dict) and "Ok" in body:
            body = body["Ok"]
        if isinstance(body, dict) and "Outputs" in body:
            body = body["Outputs"]
        return len([1 for obj in body.values()
                    if isinstance(obj, dict) and obj.get("logical") is not None])
    except (ValueError, AttributeError):
        return None


def startup_identity(log_text):
    """Parse only the two advertised Niri startup IDs, not unrelated paths."""
    display = re.findall(r"listening on Wayland socket:\s*(wayland-[0-9]+)",
                         log_text)
    ipc = re.findall(r"IPC listening on:\s*(/\S+?\.sock)(?:\s|$)",
                    log_text, flags=re.MULTILINE)
    return (display[-1] if display else None, ipc[-1] if ipc else None)


def alive_ipc(path):
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
            client.settimeout(0.4)
            client.connect(str(path))
        return True
    except (OSError, ValueError):
        return False


def trim_log(path):
    if path.is_file() and path.stat().st_size > MAX_LOG:
        with path.open("rb") as stream:
            first = stream.read(MAX_LOG // 2)
            stream.seek(-MAX_LOG // 2, os.SEEK_END)
            last = stream.read()
        path.write_bytes(first + b"\n[PRIVATE LOG OMITTED]\n" + last)


def stop_owned(proc):
    if proc is None or proc.poll() is not None:
        # Do not signal a numeric process group after its owner exited:
        # Linux could reuse that group ID for an unrelated application.
        return
    try:
        os.killpg(proc.pid, signal.SIGTERM)
    except ProcessLookupError:
        pass
    try:
        proc.wait(timeout=5)
    except subprocess.TimeoutExpired:
        try:
            os.killpg(proc.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        proc.wait(timeout=3)


def run_nested(niri, folder, host_display, host_ipc, host_outputs):
    result = {
        "status": "inconclusive", "reason": None,
        "nested_compositor_started": False,
        "distinct_nested_wayland_and_ipc": False,
        "nested_active_output_count": 0,
        "nested_preexisting_abyss_layer": "not_checked",
        "child_exit_code": None,
        "child_production_layer_result": "not_run",
        "child_published_report": None,
        "nested_compositor_stopped": False,
        "host_output_count_unchanged": False,
        "pointer_input_mask": "not_tested",
        "host_shell_or_config": "not_changed",
    }
    folder.mkdir(mode=0o700)
    config = folder / "nested.kdl"
    config.write_text('layout {\n    background-color "#000000"\n}\n',
                      encoding="utf-8")
    nested_log = folder / "nested-niri.private.log"
    child_log = folder / "production-child.private.log"
    env = dict(os.environ)
    env.pop("NIRI_SOCKET", None)
    env.update({
        "NIRI_CONFIG": str(config),
        "XDG_CONFIG_HOME": str(folder / "config"),
        "XDG_DATA_HOME": str(folder / "data"),
        "XDG_CACHE_HOME": str(folder / "cache"),
        "XDG_STATE_HOME": str(folder / "state"),
        "WAYLAND_DISPLAY": host_display,
    })
    for item in ("config", "data", "cache", "state"):
        (folder / item).mkdir()
    proc = None
    nested_ipc = None
    try:
        with nested_log.open("wb") as output:
            proc = subprocess.Popen([niri], env=env, stdout=output,
                                    stderr=subprocess.STDOUT,
                                    start_new_session=True)
        deadline = time.monotonic() + 20
        while time.monotonic() < deadline:
            if proc.poll() is not None:
                result["reason"] = "nested_niri_exited_before_ipc"
                break
            text = nested_log.read_text(encoding="utf-8", errors="replace")[:MAX_LOG]
            display, path = startup_identity(text)
            if display and path and display != host_display and path != host_ipc:
                runtime = Path(os.environ["XDG_RUNTIME_DIR"]).resolve()
                candidate = Path(path).resolve()
                if candidate.parent != runtime or not candidate.is_socket():
                    result["reason"] = "nested_ipc_not_private_runtime_socket"
                    break
                count = inventory(niri, path)
                if count is not None and count > 0:
                    result["nested_compositor_started"] = True
                    result["distinct_nested_wayland_and_ipc"] = True
                    result["nested_active_output_count"] = count
                    nested_ipc = path
                    nested_display = display
                    break
            time.sleep(0.4)
        if not result["nested_compositor_started"] and not result["reason"]:
            result["reason"] = "nested_niri_not_ready_within_bound"
        if result["nested_compositor_started"]:
            # Verify the child can never select the host niri socket.
            child_env = dict(os.environ)
            child_env.update({"NIRI_SOCKET": nested_ipc,
                              "WAYLAND_DISPLAY": nested_display})
            probe = subprocess.run(
                [niri, "msg", "-j", "layers"], env=child_env,
                capture_output=True, text=True, timeout=5
            )
            if probe.returncode:
                result["reason"] = "nested_niri_layers_api_unavailable"
            else:
                try:
                    layers = json.loads(probe.stdout)
                    if isinstance(layers, dict):
                        layers = layers.get("Ok", layers.get("layers"))
                    if isinstance(layers, dict):
                        layers = layers.get("Layers", layers.get("layers"))
                    if not isinstance(layers, list):
                        raise ValueError("layers schema")
                    existing = sum(isinstance(x, dict)
                                   and x.get("namespace") == "hadalis:abyss-perimeter"
                                   for x in layers)
                    result["nested_preexisting_abyss_layer"] = (
                        "absent" if existing == 0 else "present"
                    )
                    if existing:
                        result["reason"] = "nested_niri_already_owns_abyss_layer"
                except (ValueError, AttributeError):
                    result["reason"] = "nested_niri_layers_schema_unknown"
            if result["reason"] is None:
                # The audited child does its own source audit, private build,
                # two-stage production test and sanitized GitHub publication.
                child = None
                try:
                    with child_log.open("wb") as stream:
                        child = subprocess.run(
                            [sys.executable, INNER,
                             "--acknowledge-temporary-layer"],
                            env=child_env, stdout=stream,
                            stderr=subprocess.STDOUT, timeout=1250
                        )
                    result["child_exit_code"] = child.returncode
                except subprocess.TimeoutExpired:
                    result["child_exit_code"] = 124
                    result["reason"] = "production_child_timed_out"
                details = child_log.read_text(encoding="utf-8",
                                              errors="replace")[:MAX_LOG]
                kind = re.findall(
                    r"^PRODUCTION_LAYER_RESULT:\s*(pass|failed|inconclusive)\s*$",
                    details, re.MULTILINE
                )
                report = re.findall(
                    r"^REPORT_PUBLISHED:\s*(docs/wull-production-layer-[\w-]+\.json)\s*$",
                    details, re.MULTILINE
                )
                if kind:
                    result["child_production_layer_result"] = kind[-1]
                if report:
                    result["child_published_report"] = report[-1]
                if result["reason"] is None:
                    if child is None or child.returncode != 0 or not report:
                        result["reason"] = "production_child_not_published"
                    elif result["child_production_layer_result"] == "pass":
                        result["status"] = "pass"
                    elif result["child_production_layer_result"] == "failed":
                        result["status"] = "failed"
                        result["reason"] = "production_child_failed"
                    else:
                        result["reason"] = "production_child_inconclusive"
    except (OSError, subprocess.TimeoutExpired):
        result["reason"] = result["reason"] or "nested_launch_or_ipc_unavailable"
    finally:
        stop_owned(proc)
        trim_log(nested_log)
        trim_log(child_log)
        if nested_ipc is None:
            # If launch failed, any child IPC path would be in the private log.
            result["nested_compositor_stopped"] = proc is None or proc.poll() is not None
        else:
            deadline = time.monotonic() + 5
            while time.monotonic() < deadline and alive_ipc(nested_ipc):
                time.sleep(.25)
            result["nested_compositor_stopped"] = not alive_ipc(nested_ipc)
        result["host_output_count_unchanged"] = (
            inventory(niri, host_ipc) == host_outputs
        )
        if not result["nested_compositor_stopped"]:
            result["status"] = "failed"
            result["reason"] = "nested_ipc_still_alive_after_cleanup"
        elif not result["host_output_count_unchanged"]:
            result["status"] = "inconclusive"
            result["reason"] = "host_output_inventory_changed"
    return result


def publish(report, path):
    for attempt in range(4):
        status = subprocess.run(
            ["git", "push", "origin", "HEAD:refs/heads/dev"],
            capture_output=True, timeout=50
        )
        if status.returncode == 0:
            return
        if attempt == 3:
            raise RuntimeError("Report push failed; local report remains")
        if not clean() or git("diff-tree", "--no-commit-id",
                              "--name-only", "-r", "HEAD") != str(path):
            raise RuntimeError("Cannot rebase anything except own unpublished receipt")
        ancestor = git("rev-parse", "HEAD^")
        remote = fetch()
        audit(remote)
        if subprocess.run(["git", "merge-base", "--is-ancestor", ancestor, remote],
                          capture_output=True, timeout=10).returncode:
            raise RuntimeError("Unexpected remote history")
        git("rebase", "--onto", remote, ancestor)
        if not clean() or git("diff-tree", "--no-commit-id",
                              "--name-only", "-r", "HEAD") != str(path):
            raise RuntimeError("Own sanitized report changed during rebase")
        report["publication_parent_sha"] = git("rev-parse", "HEAD^")
        path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        git("add", "--", str(path))
        if git("diff", "--cached", "--name-only") != str(path):
            raise RuntimeError("Unexpected staged report paths")
        git("commit", "--amend", "--no-edit")


def main():
    os.umask(0o077)
    if sys.argv[1:] != ["--acknowledge-nested-niri"]:
        raise RuntimeError("Explicit opt-in required: --acknowledge-nested-niri")
    if Path.cwd().resolve() != Path(git("rev-parse", "--show-toplevel")).resolve():
        raise RuntimeError("Run from Hadalis repository root")
    if git("symbolic-ref", "--quiet", "--short", "HEAD") != "dev" or not clean():
        raise RuntimeError("A clean dev checkout is required")
    origin = git("remote", "get-url", "origin")
    push_urls = git("remote", "get-url", "--push", "--all", "origin").splitlines()
    if origin not in ORIGINS or len(push_urls) != 1 or push_urls[0] not in ORIGINS:
        raise RuntimeError("Unexpected repository remote")
    remote = fetch()
    audit(remote)
    git("merge", "--ff-only", remote)
    if not clean():
        raise RuntimeError("Source changed after fast-forward")
    source = git("rev-parse", "HEAD")
    root = Path.cwd().resolve()
    timestamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    token = secrets.token_hex(4)
    state = Path(os.environ.get("XDG_STATE_HOME",
                               str(Path.home() / ".local/state"))).resolve()
    folder = state / "hadalis" / ("wull-nested-niri-" + timestamp + "-" + token)
    if root == folder or root in folder.parents:
        raise RuntimeError("Private state directory cannot reside in checkout")
    folder.mkdir(mode=0o700, parents=True, exist_ok=False)
    print("EXACT_SOURCE_SHA:", source, flush=True)
    print("PRIVATE_LOG_DIRECTORY:", folder, flush=True)
    niri = shutil.which("niri")
    host_ipc = os.environ.get("NIRI_SOCKET", "")
    host_display = os.environ.get("WAYLAND_DISPLAY", "")
    runtime = os.environ.get("XDG_RUNTIME_DIR", "")
    reason = None
    observations = None
    if not niri or not host_ipc or not host_display or not runtime:
        reason = "missing_host_niri_or_wayland_environment"
    elif not Path(host_ipc).is_socket():
        reason = "missing_host_niri_ipc"
    else:
        count = inventory(niri, host_ipc)
        if count is None or count == 0:
            reason = "host_niri_outputs_unavailable"
        else:
            observations = run_nested(niri, folder / "nested", host_display,
                                      host_ipc, count)
    result = ("inconclusive" if reason else observations["status"])
    report = {
        "kind": "wull_manual_nested_niri_production_probe",
        "source_sha": source,
        "status": result,
        "preflight_reason": reason,
        "scope": "nested_niri_owned_production_layer_only",
        "observation": observations,
        "host_user_config_read_or_changed": False,
        "host_shell_stopped": False,
        "native_pointer_passthrough": "not_run",
        "canonical_validation": "not_run",
        "private_logs": "local_only",
    }
    print("NESTED_NIRI_PROBE_RESULT:", result, flush=True)
    print("NESTED_NIRI_PROBE_REASON:",
          reason or observations.get("reason"), flush=True)
    if not clean():
        raise RuntimeError("Unexpected checkout changes before publication")
    latest = fetch()
    audit(latest)
    if subprocess.run(
        ["git", "merge-base", "--is-ancestor", source, latest],
        capture_output=True, timeout=10
    ).returncode:
        raise RuntimeError("Remote does not descend from observed source")
    git("merge", "--ff-only", latest)
    if not clean():
        raise RuntimeError("Checkout changed while refreshing publication parent")
    report["publication_parent_sha"] = git("rev-parse", "HEAD")
    path = Path("docs") / (
        "wull-nested-niri-" + timestamp + "-" + token
        + "-" + source[:12] + ".json"
    )
    if path.exists():
        raise RuntimeError("Receipt path already exists")
    path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    git("add", "--", str(path))
    if git("diff", "--cached", "--name-only") != str(path) or (
        git("diff", "--name-only") or
        git("ls-files", "--others", "--exclude-standard")
    ):
        raise RuntimeError("Unexpected changes while staging report")
    git("commit", "-m", "test(wull): publish bounded nested Niri host proof",
        "--", str(path))
    publish(report, path)
    print("REPORT_PUBLISHED:", path, flush=True)


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError, ValueError, subprocess.TimeoutExpired,
            subprocess.CalledProcessError) as exc:
        print("STOP:", exc, file=sys.stderr)
        print("Private nested-compositor logs remain local if created.",
              file=sys.stderr)
        sys.exit(1)
