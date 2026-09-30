from __future__ import annotations

import json
from pathlib import Path
import subprocess
import time

from .model import (CUSTOM_CONTINUATION_PROMPT, CUSTOM_ROTATION_PROMPT,
                    DEFAULT_ID, MAX_PROFILES, MAINTENANCE_DEFAULTS, PROFILE_DEFAULTS,
                    default_prompt, new_profile, update_profile)
from .store import change, change_state, event, profile_state, read_snapshot

UNITS = {
    "chatgpt": "hadalis-chatgpt.service",
    "worker": "hadalis-worker.service",
    "bridge": "hadalis-chat-bridge.service",
}
SERVICE_ACTIONS = {"start", "stop", "restart"}
PROFILE_ACTIONS = {"start", "pause", "resume", "stop", "restart"}
HEARTBEAT_STALE_SECONDS = 180
DISPATCH_ACK_SECONDS = 12
ROOT = Path(__file__).resolve().parents[2]


def _runtime_unit_problem(services: dict) -> str:
    """Detect an active but stale systemd unit from another repo checkout."""
    bridge = services["bridge"]
    working_dir = bridge.get("working_directory")
    if working_dir and Path(working_dir).resolve() != ROOT:
        return (f"Chat bridge uses old checkout {working_dir}; current checkout is {ROOT}. "
                "Reinstall its user units from this checkout with "
                "python3 scripts/install-hadalis-automation.py --enable-now")
    entry = bridge.get("exec_start") or ""
    if entry and "automation.manager.daemon" not in entry:
        return ("Installed chat bridge does not run automation.manager.daemon. "
                "Reinstall user units with python3 scripts/install-hadalis-automation.py --enable-now")
    return ""



def _ensure_runtime_services() -> None:
    """Start the consumer of a profile command, not only its desired state."""
    current = service_states()
    required = ("chatgpt", "worker", "bridge")
    unavailable = [UNITS[key] for key in required
                   if current[key]["state"] == "unavailable"]
    if unavailable:
        raise RuntimeError(
            "Automation units unavailable: " + ", ".join(unavailable) +
            "; run python3 scripts/install-hadalis-automation.py --enable-now"
        )
    for key in required:
        if current[key]["state"] == "active":
            continue
        try:
            result = subprocess.run(
                ["systemctl", "--user", "start", UNITS[key]],
                capture_output=True, text=True, timeout=20, check=False,
            )
        except (OSError, subprocess.TimeoutExpired) as exc:
            raise RuntimeError(f"could not start {UNITS[key]}: {exc}") from exc
        if result.returncode:
            raise RuntimeError(
                f"could not start {UNITS[key]}: " +
                (result.stderr or result.stdout).strip()[:350]
            )
    actual = service_states()
    mismatch = _runtime_unit_problem(actual)
    if mismatch:
        raise RuntimeError(mismatch)
    inactive = [f'{UNITS[key]} ({actual[key]["state"]})'
                for key in required if actual[key]["state"] != "active"]
    if inactive:
        raise RuntimeError(
            "Automation did not become active: " + ", ".join(inactive) +
            "; inspect journalctl --user -u hadalis-chat-bridge.service"
        )


def control_unit_name(key: str) -> str:
    return UNITS[key]


def _scheduler_problem(services: dict, state: dict, now: int) -> str:
    mismatch = _runtime_unit_problem(services)
    if mismatch:
        return mismatch
    bridge = services["bridge"]
    if bridge["state"] != "active":
        detail = bridge.get("result") or bridge.get("detail") or "not running"
        return f'Chat bridge is {bridge["state"]} ({detail}); start the Automation services'
    heartbeat = state.get("manager_heartbeat_at_unix")
    if type(heartbeat) is int and now - heartbeat > HEARTBEAT_STALE_SECONDS:
        return (f"Chat bridge scheduler heartbeat is older than {HEARTBEAT_STALE_SECONDS}s; "
                "inspect its user journal")
    for key in ("chatgpt", "worker"):
        service = services[key]
        if service["state"] != "active":
            return f"{control_unit_name(key)} is {service['state']} ({service.get('result') or service.get('detail') or 'not running'})"
    if heartbeat is None:
        due = [item.get("next_run_at_unix") for item in state["profiles"].values()
               if item.get("desired") == "run" and type(item.get("next_run_at_unix")) is int]
        if due and now - min(due) > HEARTBEAT_STALE_SECONDS:
            return "Chat bridge is active but has never reported a scheduler tick"
    return ""




def service_states() -> dict:
    result = {}
    for key, unit in UNITS.items():
        try:
            output = subprocess.run(
                ["systemctl", "--user", "show", unit,
                 "--property=LoadState,ActiveState,SubState,Result,ExecMainStatus,WorkingDirectory,ExecStart"],
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
                           "detail": values.get("SubState", ""), "result": outcome,
                           "exec_main_status": values.get("ExecMainStatus", ""),
                           "working_directory": values.get("WorkingDirectory", ""),
                           "exec_start": values.get("ExecStart", "")}
        except (OSError, subprocess.TimeoutExpired):
            result[key] = {"unit": unit, "state": "unavailable",
                           "detail": "systemd user manager unavailable", "result": "",
                           "exec_main_status": "", "working_directory": "",
                           "exec_start": ""}
    return result


def status() -> dict:
    config, state, issues = read_snapshot()
    services = service_states()
    problem = _scheduler_problem(services, state, int(time.time()))
    if problem and any(item["desired"] == "run" and
                       (item["status"] != "scheduler_unavailable" or
                        item["last_error"] != problem)
                       for item in state["profiles"].values()):
        def mark_unavailable(_config: dict, runtime: dict):
            for profile_id, item in runtime["profiles"].items():
                if item["desired"] != "run":
                    continue
                if item["status"] == "scheduler_unavailable" and item["last_error"] == problem:
                    continue
                item["status"] = "scheduler_unavailable"
                item["last_error"] = problem[:2000]
                item["last_activity_at_unix"] = int(time.time())
                event(runtime, profile_id, "scheduler_unavailable", problem)
        change_state(mark_unavailable)
        config, state, issues = read_snapshot()
    return {"ok": True, "config": config, "runtime": state, "issues": issues,
            "services": services, "capabilities": {
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
        detail = (result.stderr or result.stdout).strip()[:2000]
        change_state(lambda _config, state: event(
            state, None, "service_action_failed", f"{action} {UNITS[key]}: {detail}"))
        raise RuntimeError(detail)
    change_state(lambda _config, state: event(state, None, "service_" + action, UNITS[key]))
    return {"ok": True}


def _await_dispatch(profile_id: str) -> None:
    """A healthy unit is not proof that its scheduler has consumed Start."""
    deadline = time.monotonic() + DISPATCH_ACK_SECONDS
    last_reason = ""
    while time.monotonic() < deadline:
        _config, runtime, issues = read_snapshot()
        item = runtime["profiles"].get(profile_id)
        if item is None:
            raise RuntimeError("profile disappeared during dispatch")
        if issues:
            raise RuntimeError("Automation config invalid: " + "; ".join(issues)[:1000])
        now = int(time.time())
        heartbeat = runtime.get("manager_heartbeat_at_unix")
        fresh = type(heartbeat) is int and 0 <= now - heartbeat <= 15
        owner = runtime["owner_id"]
        if item["status"] == "invalid_configuration":
            raise RuntimeError(item["last_error"])
        if fresh and owner == profile_id and item["status"] != "scheduler_unavailable":
            # A restart can legitimately wait for its existing in-flight
            # response. Ownership + scheduler heartbeat is its receipt.
            return
        if fresh and owner not in (None, profile_id) and item["status"] == "waiting_owner":
            # Another owner is still completing its current response safely.
            return
        if not fresh:
            last_reason = "no fresh scheduler heartbeat"
        elif owner is None:
            last_reason = "scheduler is alive but did not claim the due profile"
        else:
            last_reason = f"profile is queued behind owner {owner}"
        time.sleep(0.25)
    raise RuntimeError(
        "Start was saved but was not dispatched: " + (last_reason or "no scheduler acknowledgement")
        + "; inspect Automation Activity and hadalis-chat-bridge.service journal. "
        "If the bridge still runs code from before this update, restart it "
        "after its current response is safely finished."
    )


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
            # A button click is not a scheduler tick; never falsely claim
            # that a previously owned profile is actively continuing.
            if action == "restart":
                item["status"] = "restart_queued" if item["pending"] else "scheduled"
                if item["job_id"] and item["pending"] is None:
                    event(state, profile_id, "job_wait_abandoned", item["job_id"])
                    item["job_id"] = None
                    item["next_job_poll_at_unix"] = None
                    item["job_poll_errors"] = 0
            elif not (state["owner_id"] == profile_id and
                      (item["pending"] is not None or item["job_id"])):
                item["status"] = "scheduled"
            item["next_run_at_unix"] = int(time.time())
            item["status_detail"] = ""
            if state["owner_id"] != profile_id:
                state["requested_profile_id"] = profile_id
                previous_id = state["owner_id"]
                if previous_id:
                    prior = state["profiles"][previous_id]
                    if prior["desired"] != "stopped":
                        prior["desired"] = "stopped"
                        if not (prior["pending"] is not None and prior["status"] in {
                                "stream_failed", "transport_unavailable", "waiting_desktop"}):
                            prior["status"] = "stopping"
                        prior["status_detail"] = "Yielding ChatGPT transport to " + profile["name"]
                        event(state, previous_id, "takeover_requested",
                              f"Explicit Start for {profile['name']}; finish current response first")
                    item["status"] = "waiting_owner"
                    item["status_detail"] = (
                        f"Waiting for {previous_id} to release its ChatGPT chat "
                        "after its current response finishes."
                        + (" The prior session has an unresolved response; inspect Activity "
                           "and recover it before this profile can run."
                           if prior["pending"] is not None and prior["status"] in {
                               "stream_failed", "transport_unavailable", "waiting_desktop"}
                           else ""))
                    event(state, profile_id, "waiting_owner", item["status_detail"])
            if action == "resume":
                item["poll_errors"] = 0
                item["job_poll_errors"] = 0
                if item["pending"] is not None:
                    item["pending"]["poll_after_unix"] = int(time.time())
                    item["pending"]["stream_retry_attempts"] = 0
            if action == "restart":
                item["request"] = "restart"
            elif action == "start" and state["owner_id"] != profile_id:
                item["request"] = "new"
        else:
            item["desired"] = "paused" if action == "pause" else "stopped"
            item["status_detail"] = ""
            if state.get("requested_profile_id") == profile_id:
                state["requested_profile_id"] = None
            item["status"] = "pausing" if state["owner_id"] == profile_id else (
                "paused" if action == "pause" else "idle")
            if state["owner_id"] != profile_id:
                item["request"] = None
        event(state, profile_id, action)

    change_state(mutate)
    if action in {"start", "resume", "restart"}:
        try:
            _ensure_runtime_services()
            _await_dispatch(profile_id)
        except RuntimeError as exc:
            def startup_failed(_config: dict, state: dict):
                item = state["profiles"][profile_id]
                item["status"] = "scheduler_unavailable"
                item["last_error"] = str(exc)[:2000]
                item["status_detail"] = ""
                item["last_activity_at_unix"] = int(time.time())
                event(state, profile_id, "start_failed", item["last_error"])
            change_state(startup_failed)
            raise
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
                if field == "project_name" and state["owner_id"] == profile_id:
                    raise ValueError("stop the active profile before changing its project")
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


def reset_prompt(profile_id: str, field: str) -> dict:
    defaults = {"prompt": default_prompt(),
                "continuation_prompt": PROFILE_DEFAULTS["continuation_prompt"] if profile_id == DEFAULT_ID else CUSTOM_CONTINUATION_PROMPT,
                "rotation_prompt": PROFILE_DEFAULTS["rotation_prompt"] if profile_id == DEFAULT_ID else CUSTOM_ROTATION_PROMPT}
    if field not in defaults:
        raise ValueError("prompt field not allowlisted")

    def mutate(config: dict, state: dict):
        for index, profile in enumerate(config["profiles"]):
            if profile["id"] == profile_id:
                config["profiles"][index] = update_profile(profile, {field: defaults[field]})
                event(state, profile_id, "prompt_reset", field)
                return
        raise ValueError("profile not found")
    change(mutate)
    return {"ok": True, "reload_draft": True}


def set_maintenance(field: str, value_json: str, confirm_delete: bool = False) -> dict:
    if field not in MAINTENANCE_DEFAULTS:
        raise ValueError("maintenance field not allowlisted")
    value = json.loads(value_json)
    if type(value) is not bool:
        raise ValueError("maintenance value must be boolean")
    if field == "delete_completed" and value and not confirm_delete:
        raise ValueError("delete requires explicit confirmation")

    def mutate(config: dict, state: dict):
        if value and field in {"archive_completed", "delete_completed"}:
            other = "delete_completed" if field == "archive_completed" else "archive_completed"
            if config["maintenance"][other]:
                raise ValueError("archive and delete are mutually exclusive")
        config["maintenance"][field] = value
        event(state, None, "maintenance_updated", field)
    change(mutate)
    return {"ok": True}


def remove_profile(profile_id: str) -> dict:
    # If a dead scheduler stranded ownership, a fully stopped profile without
    # an in-flight ChatGPT response can release that stale lease safely.
    # Never discard a pending (possibly submitted) prompt.
    config, state, _issues = read_snapshot()
    if state["owner_id"] == profile_id:
        item = state["profiles"][profile_id]
        if item["desired"] != "stopped" or item["pending"] is not None:
            raise ValueError("stop the profile and finish its current response before removing it")
        if not _scheduler_problem(service_states(), state, int(time.time())):
            raise ValueError("the scheduler still owns this profile; retry after it releases the chat")

    def mutate(config: dict, state: dict):
        if profile_id == "strict-lossless-research":
            raise ValueError("the built-in profile can be disabled but not removed")
        if profile_id not in state["profiles"]:
            raise ValueError("profile not found")
        if state["profiles"][profile_id]["pending"] is not None:
            raise ValueError("cannot remove profile with a pending ChatGPT response")
        if state["owner_id"] == profile_id:
            item = state["profiles"][profile_id]
            if item["desired"] != "stopped" or item["pending"] is not None:
                raise ValueError("the profile is still running or has a pending response")
            state["owner_id"] = None
            event(state, profile_id, "stale_owner_released")
        config["profiles"] = [item for item in config["profiles"] if item["id"] != profile_id]
        if state.get("requested_profile_id") == profile_id:
            state["requested_profile_id"] = None
        state["profiles"].pop(profile_id)
        event(state, profile_id, "removed", "ChatGPT history retained")
    change(mutate)
    return {"ok": True}
