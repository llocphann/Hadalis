#!/usr/bin/env python3
from __future__ import annotations

import argparse
import fcntl
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import time
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
QUEUE = "automation/queue/pending"
RESULTS = "automation/results"
JOB_RE = re.compile(r"^JOB-[A-Za-z0-9._-]+$")
SHA_RE = re.compile(r"^[0-9a-f]{40}$")
POLL = float(os.environ.get("HADALIS_WORKER_POLL_SECONDS", "10"))
MAX_CAPTURE = int(os.environ.get("HADALIS_WORKER_MAX_CAPTURE_BYTES", "131072"))
MAX_TIMEOUT = int(os.environ.get("HADALIS_WORKER_MAX_TIMEOUT_SECONDS", "3600"))
ENV_KEYS = {
    "PATH", "HOME", "USER", "LOGNAME", "LANG", "LC_ALL",
    "DISPLAY", "WAYLAND_DISPLAY", "XDG_RUNTIME_DIR", "NIRI_SOCKET",
    "DBUS_SESSION_BUS_ADDRESS",
}


def run(argv: list[str], *, cwd: Path = ROOT, timeout: float | None = None,
        env: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        argv, cwd=cwd, env=env, text=True, capture_output=True,
        check=False, timeout=timeout,
    )


def git(*args: str, timeout: int = 120) -> subprocess.CompletedProcess[str]:
    return run(["git", *args], timeout=timeout)


def state_root() -> Path:
    base = Path(os.environ.get(
        "XDG_STATE_HOME", str(Path.home() / ".local" / "state")
    ))
    path = base / "hadalis-automation" / "worker"
    path.mkdir(parents=True, exist_ok=True)
    return path


def fetch_dev() -> None:
    result = git("fetch", "origin", "dev")
    if result.returncode != 0:
        raise RuntimeError(f"git fetch failed: {result.stderr.strip()}")


def remote_url() -> str:
    result = git("remote", "get-url", "origin")
    if result.returncode != 0:
        raise RuntimeError(f"origin unavailable: {result.stderr.strip()}")
    return result.stdout.strip()


def pending_paths() -> list[str]:
    result = git("ls-tree", "-r", "--name-only", "origin/dev", QUEUE)
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip())
    return sorted(
        line.strip() for line in result.stdout.splitlines()
        if line.strip().endswith(".json")
    )


def result_exists(job_id: str) -> bool:
    result = git(
        "cat-file", "-e", f"origin/dev:{RESULTS}/{job_id}.json",
        timeout=30,
    )
    return result.returncode == 0


def remote_text(path: str) -> str:
    result = git("show", f"origin/dev:{path}", timeout=30)
    if result.returncode != 0:
        raise RuntimeError(f"cannot read {path}: {result.stderr.strip()}")
    return result.stdout


def introducing_commit(path: str) -> str:
    result = git("log", "-1", "--format=%H", "origin/dev", "--", path, timeout=30)
    value = result.stdout.strip()
    if result.returncode != 0 or SHA_RE.fullmatch(value) is None:
        raise RuntimeError(f"cannot resolve job commit for {path}")
    return value


def first_parent(commit: str) -> str:
    result = git("rev-parse", f"{commit}^", timeout=30)
    value = result.stdout.strip()
    if result.returncode != 0 or SHA_RE.fullmatch(value) is None:
        raise RuntimeError(f"cannot resolve parent for {commit}")
    return value


def validate_job(path: str, raw: str) -> dict[str, Any]:
    job_id = Path(path).stem
    if JOB_RE.fullmatch(job_id) is None:
        raise ValueError("unsafe job filename")
    data = json.loads(raw)
    if not isinstance(data, dict) or data.get("id") != job_id:
        raise ValueError("job id must match filename")
    base_sha = data.get("base_sha")
    if not isinstance(base_sha, str) or SHA_RE.fullmatch(base_sha) is None:
        raise ValueError("base_sha must be a full SHA")
    actions = data.get("actions")
    if not isinstance(actions, list) or not actions:
        raise ValueError("actions must be a non-empty list")
    for action in actions:
        if not isinstance(action, dict) or set(action) != {"exec"}:
            raise ValueError("each action must contain only exec")
        spec = action["exec"]
        if not isinstance(spec, dict):
            raise ValueError("exec must be an object")
        argv = spec.get("argv")
        if (not isinstance(argv, list) or not argv or
                any(not isinstance(item, str) or not item for item in argv)):
            raise ValueError("exec.argv must be a non-empty string list")
        if not isinstance(spec.get("cwd", "."), str):
            raise ValueError("exec.cwd must be a string")
        timeout = spec.get("timeout_seconds", 600)
        if not isinstance(timeout, int) or not 0 < timeout <= MAX_TIMEOUT:
            raise ValueError("exec.timeout_seconds is out of range")
    return data


def safe_cwd(workspace: Path, relative: str) -> Path:
    root = workspace.resolve()
    target = (workspace / relative).resolve()
    if target != root and root not in target.parents:
        raise ValueError("exec.cwd escapes workspace")
    if not target.is_dir():
        raise ValueError(f"exec.cwd does not exist: {relative}")
    return target


def clipped(text: str | bytes | None) -> tuple[str, bool]:
    if text is None:
        return "", False
    if isinstance(text, bytes):
        raw = text
    else:
        raw = text.encode("utf-8", errors="replace")
    if len(raw) <= MAX_CAPTURE:
        return raw.decode("utf-8", errors="replace"), False
    return raw[:MAX_CAPTURE].decode("utf-8", errors="replace"), True


def exec_env() -> dict[str, str]:
    return {key: value for key, value in os.environ.items() if key in ENV_KEYS}


def workspace_for(commit: str, job_id: str) -> Path:
    runs = state_root() / "runs"
    runs.mkdir(exist_ok=True)
    path = Path(tempfile.mkdtemp(prefix=f"{job_id}-", dir=runs))
    shutil.rmtree(path)
    clone = run(
        ["git", "clone", "--no-hardlinks", "--no-checkout", str(ROOT), str(path)],
        timeout=300,
    )
    if clone.returncode != 0:
        raise RuntimeError(f"workspace clone failed: {clone.stderr.strip()}")
    checkout = run(
        ["git", "checkout", "--detach", commit], cwd=path, timeout=120
    )
    if checkout.returncode != 0:
        raise RuntimeError(f"workspace checkout failed: {checkout.stderr.strip()}")
    return path


def execute(data: dict[str, Any], commit: str) -> dict[str, Any]:
    started = int(time.time())
    workspace = workspace_for(commit, data["id"])
    action_results: list[dict[str, Any]] = []
    status = "passed"
    try:
        for index, action in enumerate(data["actions"]):
            spec = action["exec"]
            argv = spec["argv"]
            cwd = safe_cwd(workspace, spec.get("cwd", "."))
            timeout = spec.get("timeout_seconds", 600)
            try:
                result = run(argv, cwd=cwd, timeout=timeout, env=exec_env())
                out, out_cut = clipped(result.stdout)
                err, err_cut = clipped(result.stderr)
                action_results.append({
                    "index": index, "argv": argv,
                    "cwd": str(cwd.relative_to(workspace)),
                    "exit_code": result.returncode,
                    "stdout": out, "stderr": err,
                    "stdout_truncated": out_cut,
                    "stderr_truncated": err_cut,
                    "timed_out": False,
                })
                if result.returncode != 0:
                    status = "failed"
                    break
            except subprocess.TimeoutExpired as exc:
                out, out_cut = clipped(exc.stdout)
                err, err_cut = clipped(exc.stderr)
                action_results.append({
                    "index": index, "argv": argv,
                    "cwd": str(cwd.relative_to(workspace)),
                    "exit_code": None,
                    "stdout": out, "stderr": err,
                    "stdout_truncated": out_cut,
                    "stderr_truncated": err_cut,
                    "timed_out": True,
                })
                status = "failed"
                break
    finally:
        shutil.rmtree(workspace, ignore_errors=True)
    return {
        "job": data["id"], "base_sha": data["base_sha"],
        "job_commit": commit, "status": status,
        "started_at_unix": started, "finished_at_unix": int(time.time()),
        "actions": action_results,
    }


def publish(job_id: str, payload: dict[str, Any]) -> None:
    target = f"{RESULTS}/{job_id}.json"
    remote = remote_url()
    publish_dir = state_root() / "publish"
    publish_dir.mkdir(exist_ok=True)
    for attempt in range(5):
        fetch_dev()
        if result_exists(job_id):
            return
        checkout = Path(tempfile.mkdtemp(prefix=f"{job_id}-", dir=publish_dir))
        shutil.rmtree(checkout)
        try:
            clone = run(
                ["git", "clone", "--branch", "dev", "--single-branch",
                 remote, str(checkout)],
                timeout=300,
            )
            if clone.returncode != 0:
                raise RuntimeError(clone.stderr.strip())
            output = checkout / target
            output.parent.mkdir(parents=True, exist_ok=True)
            output.write_text(
                json.dumps(payload, indent=2, sort_keys=True) + "\n",
                encoding="utf-8",
            )
            for argv in (
                ["git", "add", target],
                ["git", "commit", "-m", f"automation: record {job_id} result"],
            ):
                result = run(argv, cwd=checkout, timeout=120)
                if result.returncode != 0:
                    raise RuntimeError(result.stderr.strip())
            pushed = run(
                ["git", "push", "origin", "HEAD:dev"],
                cwd=checkout, timeout=180,
            )
            if pushed.returncode == 0:
                return
        finally:
            shutil.rmtree(checkout, ignore_errors=True)
        time.sleep(min((attempt + 1) * 2, 10))
    raise RuntimeError(f"failed to publish {job_id} result")


def process_one() -> bool:
    fetch_dev()
    for path in pending_paths():
        job_id = Path(path).stem
        if result_exists(job_id):
            continue
        commit = introducing_commit(path)
        try:
            data = validate_job(path, remote_text(path))
            parent = first_parent(commit)
            if parent != data["base_sha"]:
                raise ValueError(
                    f"job parent {parent} does not match base_sha {data['base_sha']}"
                )
            payload = execute(data, commit)
        except Exception as exc:
            payload = {
                "job": job_id, "status": "invalid",
                "finished_at_unix": int(time.time()),
                "error": f"{type(exc).__name__}: {exc}",
            }
        publish(job_id, payload)
        return True
    return False


def main() -> int:
    parser = argparse.ArgumentParser(description="Deterministic Hadalis local job worker")
    parser.add_argument("--once", action="store_true")
    args = parser.parse_args()
    lock_path = state_root() / "worker.lock"
    with lock_path.open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        while True:
            worked = process_one()
            if args.once:
                return 0
            if not worked:
                time.sleep(POLL)


if __name__ == "__main__":
    raise SystemExit(main())
