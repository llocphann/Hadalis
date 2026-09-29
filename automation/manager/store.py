from __future__ import annotations

from contextlib import contextmanager
import fcntl
import json
import os
from pathlib import Path
import tempfile
import time
from typing import Callable

from .model import default_config, normalize_config

EVENT_LIMIT = 100


def config_path() -> Path:
    base = Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config")))
    return base / "hadalis" / "automation.json"


def state_dir() -> Path:
    base = Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state")))
    return base / "hadalis-automation"


def state_path() -> Path:
    return state_dir() / "manager.json"


def _read(path: Path, fallback: dict) -> dict:
    if not path.exists():
        return fallback
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ValueError(f"invalid JSON at {path}; no changes made") from exc
    if not isinstance(payload, dict):
        raise ValueError(f"invalid object at {path}; no changes made")
    return payload


def _write(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    encoded = (json.dumps(payload, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
    fd, name = tempfile.mkstemp(prefix=".automation-", dir=path.parent)
    try:
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, "wb") as stream:
            stream.write(encoded)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(name, path)
    finally:
        try:
            os.unlink(name)
        except FileNotFoundError:
            pass


def profile_state() -> dict:
    return {
        "desired": "stopped", "status": "idle", "loop_state": "",
        "iterations": 0, "chat_iterations": 0, "prompts_sent": 0,
        "failures": 0, "poll_errors": 0, "job_id": None,
        "last_job_id": None, "last_result": "", "run_start_iterations": 0,
        "run_start_prompts": 0,
        "job_poll_errors": 0, "next_job_poll_at_unix": None,
        "started_at_unix": None, "chat_started_at_unix": None,
        "last_run_at_unix": None, "next_run_at_unix": None,
        "last_activity_at_unix": None, "last_success": "", "last_error": "",
        "pending": None, "request": None,
    }


def default_state(config: dict) -> dict:
    profiles = {}
    for profile in config["profiles"]:
        item = profile_state()
        if profile["enabled"] and profile["mode"] == "continuous":
            item["desired"] = "run"
            item["status"] = "scheduled"
        profiles[profile["id"]] = item
    # A stopped legacy bridge can have a connector-blocked terminal state. Do
    # not silently restart that profile during migration.
    legacy = state_dir() / "chat-bridge.json"
    if legacy.exists() and "strict-lossless-research" in profiles:
        try:
            previous = json.loads(legacy.read_text(encoding="utf-8"))
            if previous.get("state") == "connector_blocked":
                profiles["strict-lossless-research"].update({
                    "desired": "paused", "status": "connector_blocked",
                    "loop_state": "connector_blocked",
                    "last_error": "GitHub connector needs attention",
                })
        except (OSError, ValueError, AttributeError):
            profiles["strict-lossless-research"].update({
                "desired": "paused", "status": "error",
                "last_error": "Legacy bridge state is unreadable",
            })
    return {"version": 1, "owner_id": None, "profiles": profiles, "events": []}


def normalize_state(raw: dict, config: dict) -> dict:
    if raw.get("version", 1) != 1:
        raise ValueError("unsupported automation state version")
    source = raw.get("profiles", {})
    if not isinstance(source, dict):
        raise ValueError("invalid automation state profiles")
    profiles = {}
    for profile in config["profiles"]:
        item = profile_state()
        prior = source.get(profile["id"], {})
        if isinstance(prior, dict):
            item.update({key: prior[key] for key in item if key in prior})
        profiles[profile["id"]] = item
    owner = raw.get("owner_id")
    if owner not in profiles:
        owner = None
    events = raw.get("events", [])
    if not isinstance(events, list):
        events = []
    events = [event for event in events[-EVENT_LIMIT:] if isinstance(event, dict)]
    return {"version": 1, "owner_id": owner, "profiles": profiles, "events": events}


def event(state: dict, profile_id: str | None, kind: str, detail: str = "") -> None:
    state["events"] = (state["events"] + [{
        "at_unix": int(time.time()), "profile_id": profile_id,
        "kind": kind[:64], "detail": detail[:300],
    }])[-EVENT_LIMIT:]


@contextmanager
def locked_document():
    lock = state_dir() / "manager.lock"
    lock.parent.mkdir(parents=True, exist_ok=True)
    with lock.open("a+") as handle:
        fcntl.flock(handle, fcntl.LOCK_EX)
        raw_config = _read(config_path(), default_config())
        config, issues = normalize_config(raw_config)
        raw_state = _read(state_path(), default_state(config))
        state = normalize_state(raw_state, config)
        yield config, state, issues


def read_snapshot() -> tuple[dict, dict, list[str]]:
    with locked_document() as (config, state, issues):
        return config, state, issues


def change(mutator: Callable[[dict, dict], object]) -> object:
    with locked_document() as (config, state, issues):
        if issues:
            raise ValueError("invalid profiles need repair before editing: " + "; ".join(issues))
        result = mutator(config, state)
        _write(config_path(), config)
        _write(state_path(), state)
        return result


def change_state(mutator: Callable[[dict, dict], object]) -> object:
    with locked_document() as (config, state, _issues):
        result = mutator(config, state)
        _write(state_path(), state)
        return result
