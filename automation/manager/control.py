from __future__ import annotations

import json
import subprocess
import time

from .model import MAX_PROFILES, MAINTENANCE_DEFAULTS, new_profile, update_profile
from .store import change, change_state, event, profile_state, read_snapshot

UNITS = {
    "chatgpt": "hadalis-chatgpt.service",
    "worker": "hadalis-worker.service",
    "bridge": "hadalis-chat-bridge.service",
}
SERVICE_ACTIONS = {"start", "stop", "restart"}
PROFILE_ACTIONS = {"start", "pause", "resume", "stop", "restart"}


def service_states() -> dict:
    result = {}
    for key, unit in UNITS.items():
        try:
            output = subprocess.run(
                ["systemctl", "--user", "show", unit,
                 "--property=LoadState,ActiveState,SubState,Result,ExecMainStatus"],
                capture_output=True, text=True, timeout=4, check=False,
            )
            values = dict(line.split("=", 1) for line in output.stdout.splitlines() if "=" in line)
            active = values.get("ActiveState", "unknown")
            loaded = values.get("LoadState", "unknown")
            outcome = values.get("Result", "")
            if loaded != "loaded":
                state = "unavailable"
            elif active in {"active", "activating", "deactivating", "failed", "inactive"}:
                state = {"activating": "starting", "deactivating": "stopping"}.get(active, active)
            else:
                state = "unavailable"
            if key == "bridge" and state == "failed" and values.get("ExecMainStatus") == "75":
                state = "blocked"
            if key == "bridge" and state == "inactive" and outcome not in {"", "success"}:
                state = "failed"
            result[key] = {"unit": unit, "state": state,
                           "detail": values.get("SubState", ""), "result": outcome}
        except (OSError, subprocess.TimeoutExpired):
            result[key] = {"unit": unit, "state": "unavailable",
                           "detail": "systemd user manager unavailable", "result": ""}
    return result


def status() -> dict:
    config, state, issues = read_snapshot()
    return {"ok": True, "config": config, "runtime": state, "issues": issues,
            "services": service_states(), "capabilities": {
                "archive_chat": False, "delete_chat": False,
                "stuck_generation_recovery": False, "composer_recovery": False,
                "stream_poll_recovery": True, "transport_retry": False,
                "single_transport_owner": True,
            }}


def control_service(action: str, key: str) -> dict:
    if action not in SERVICE_ACTIONS or key not in UNITS:
        raise ValueError("service action or unit not allowlisted")
    result = subprocess.run(["systemctl", "--user", action, UNITS[key]],
                            capture_output=True, text=True, timeout=20, check=False)
    if result.returncode != 0:
        raise RuntimeError((result.stderr or result.stdout).strip()[:500])
    change_state(lambda _config, state: event(state, None, "service_" + action, UNITS[key]))
    return {"ok": True}


def profile_action(action: str, profile_id: str) -> dict:
    if action not in PROFILE_ACTIONS:
        raise ValueError("profile action not allowlisted")

    def mutate(config: dict, state: dict):
        profile = next((item for item in config["profiles"] if item["id"] == profile_id), None)
        if profile is None:
            raise ValueError("profile not found")
        item = state["profiles"][profile_id]
        if action in {"start", "resume", "restart"} and not profile["enabled"]:
            raise ValueError("enable the profile first")
        if action == "resume" and item["desired"] != "paused":
            raise ValueError("profile is not paused")
        if action in {"start", "resume", "restart"}:
            item["desired"] = "run"
            item["status"] = "scheduled" if state["owner_id"] != profile_id else "continuing"
            item["next_run_at_unix"] = int(time.time())
            if action == "resume":
                item["poll_errors"] = 0
                item["job_poll_errors"] = 0
                if item["pending"] is not None:
                    item["pending"]["poll_after_unix"] = int(time.time())
            if action == "restart":
                item["request"] = "restart"
            elif action == "start" and state["owner_id"] != profile_id:
                item["request"] = "new"
        else:
            item["desired"] = "paused" if action == "pause" else "stopped"
            item["status"] = "pausing" if state["owner_id"] == profile_id else (
                "paused" if action == "pause" else "idle")
            if state["owner_id"] != profile_id:
                item["request"] = None
        event(state, profile_id, action)

    change_state(mutate)
    return {"ok": True}


def create_profile(name: str, duplicate_id: str | None = None) -> dict:
    def mutate(config: dict, state: dict):
        if len(config["profiles"]) >= MAX_PROFILES:
            raise ValueError("profile limit reached")
        source = None
        if duplicate_id:
            source = next((item for item in config["profiles"] if item["id"] == duplicate_id), None)
            if source is None:
                raise ValueError("source profile not found")
        profile = new_profile(name, copy=source)
        config["profiles"].append(profile)
        state["profiles"][profile["id"]] = profile_state()
        event(state, profile["id"], "created")
        return {"ok": True, "profile_id": profile["id"]}
    return change(mutate)


def set_profile(profile_id: str, field: str, value_json: str, confirm_delete: bool = False) -> dict:
    value = json.loads(value_json)

    def mutate(config: dict, state: dict):
        for index, profile in enumerate(config["profiles"]):
            if profile["id"] == profile_id:
                config["profiles"][index] = update_profile(
                    profile, {field: value}, confirm_delete=confirm_delete)
                item = state["profiles"][profile_id]
                if field == "enabled" and value is False:
                    item["desired"] = "stopped"
                    item["status"] = "stopping" if state["owner_id"] == profile_id else "disabled"
                elif field == "enabled" and value is True:
                    item["status"] = "idle"
                event(state, profile_id, "updated", field)
                return
        raise ValueError("profile not found")

    change(mutate)
    return {"ok": True}


def set_maintenance(field: str, value_json: str, confirm_delete: bool = False) -> dict:
    if field not in MAINTENANCE_DEFAULTS:
        raise ValueError("maintenance field not allowlisted")
    value = json.loads(value_json)
    if type(value) is not bool:
        raise ValueError("maintenance value must be boolean")
    if field == "delete_completed" and value and not confirm_delete:
        raise ValueError("delete requires explicit confirmation")

    def mutate(config: dict, state: dict):
        config["maintenance"][field] = value
        event(state, None, "maintenance_updated", field)
    change(mutate)
    return {"ok": True}


def remove_profile(profile_id: str) -> dict:
    def mutate(config: dict, state: dict):
        if state["owner_id"] == profile_id:
            raise ValueError("stop the active profile before removing it")
        if profile_id == "strict-lossless-research":
            raise ValueError("the built-in profile can be disabled but not removed")
        before = len(config["profiles"])
        config["profiles"] = [item for item in config["profiles"] if item["id"] != profile_id]
        if len(config["profiles"]) == before:
            raise ValueError("profile not found")
        state["profiles"].pop(profile_id, None)
        event(state, profile_id, "removed", "ChatGPT history retained")
    change(mutate)
    return {"ok": True}
