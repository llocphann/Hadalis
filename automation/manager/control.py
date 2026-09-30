from __future__ import annotations

import json
import fcntl
import subprocess
import time

from .model import (CUSTOM_CONTINUATION_PROMPT, CUSTOM_ROTATION_PROMPT,
                    DEFAULT_ID, MAX_PROFILES, MAINTENANCE_DEFAULTS, PROFILE_DEFAULTS,
                    default_prompt, new_profile, update_profile)
from .store import change, change_state, event, profile_state, read_snapshot, state_dir

UNITS = {
    "chatgpt": "hadalis-chatgpt.service",
    "worker": "hadalis-worker.service",
    "bridge": "hadalis-chat-bridge.service",
}
SERVICE_ACTIONS = {"start", "stop", "restart"}
PROFILE_ACTIONS = {"start", "pause", "resume", "stop", "restart"}
HEARTBEAT_STALE_SECONDS = 180
DISPATCH_ACK_SECONDS = 12


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
    host = services["chatgpt"]
    if host["state"] != "active" and host.get("exec_main_status") == "76":
        return ("ChatGPT was opened without the Automation connection. "
                "Close ChatGPT once, reopen it from Applications, then press Start. "
                "Your existing response and chat history are kept.")
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
                           "exec_main_status": "", "working_directory": "", "exec_start": ""}
    return result


def status() -> dict:
    """Observe health without mutating the scheduler's own run status.

    UI status polling must not fight the manager heartbeat over its state or
    flood the 100-entry Activity ring with false recovery events.
    """
    config, state, issues = read_snapshot()
    services = service_states()
    return {"ok": True, "config": config, "runtime": state, "issues": issues,
            "services": services,
            "scheduler_problem": _scheduler_problem(services, state, int(time.time())),
            "capabilities": {
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


def _await_dispatch(profile_id: str, command_seq: int) -> None:
    """Wait for a *new* manager tick to acknowledge this specific command."""
    deadline = time.monotonic() + DISPATCH_ACK_SECONDS
    reason = "bridge has not acknowledged the new command"
    while time.monotonic() < deadline:
        _config, state, issues = read_snapshot()
        item = state["profiles"].get(profile_id)
        if item is None:
            raise RuntimeError("profile was removed before scheduler acknowledgement")
        if issues:
            raise RuntimeError("invalid Automation configuration: " + "; ".join(issues)[:1400])
        if item["status"] == "invalid_configuration":
            raise RuntimeError(item["last_error"])
        heartbeat = state.get("manager_heartbeat_at_unix")
        fresh = type(heartbeat) is int and 0 <= int(time.time()) - heartbeat <= 15
        acknowledged = state.get("command_ack_seq", 0) >= command_seq
        owner = state["owner_id"]
        if fresh and acknowledged:
            if owner == profile_id and item["desired"] == "run":
                return
            if (owner is not None and owner != profile_id and
                    item["status"] == "waiting_owner" and
                    state.get("requested_profile_id") == profile_id):
                return  # Explicitly queued for safe handover, not yet running.
            if item["desired"] != "run":
                raise RuntimeError("profile stopped before dispatch")
            reason = "manager acknowledged the request but has not claimed the due profile"
        elif not fresh:
            reason = "no fresh manager heartbeat"
        else:
            reason = "running bridge did not acknowledge this command (possibly outdated code)"
        time.sleep(0.25)
    raise RuntimeError(
        "Start was saved but was not dispatched: " + reason +
        ". Check the chat bridge journal; if it runs outdated code, update "
        "its source checkout and restart it after any pending response is safe."
    )


def profile_action(action: str, profile_id: str) -> dict:
    if action not in PROFILE_ACTIONS:
        raise ValueError("profile action not allowlisted")

    def mutate(config: dict, state: dict):
        profile = next((p for p in config["profiles"] if p["id"] == profile_id), None)
        if profile is None:
            raise ValueError("profile not found")
        item = state["profiles"][profile_id]
        if item.get("remove_requested"):
            raise ValueError("this profile is being removed; wait for the scheduler")
        if action in {"start", "resume", "restart"} and item.get("parked_pending"):
            raise ValueError(
                "this profile has a parked unresolved response; reconcile its original "
                "ChatGPT conversation before starting another run")
        if action in {"start", "resume", "restart"} and not profile["enabled"]:
            raise ValueError("enable the profile first")
        if action == "resume" and item["desired"] != "paused":
            raise ValueError("profile is not paused")
        if item.get("parked_pending") and action in {"pause", "stop"}:
            item["desired"] = "stopped"
            item["status"] = "parked_unresolved"
            item["request"] = None
            event(state, profile_id, action)
            return None
        now = int(time.time())
        if action in {"start", "resume", "restart"}:
            item["desired"] = "run"
            item["next_run_at_unix"] = now
            item["status_detail"] = ""
            state["command_seq"] += 1
            item["command_seq"] = state["command_seq"]

            # A previous prompt may already have reached ChatGPT. Even after
            # a polling failure, explicitly pressing Start/Restart may only
            # re-observe that *same* baseline, never submit another prompt.
            if state["owner_id"] == profile_id and item["pending"] is not None:
                item["poll_errors"] = 0
                item["pending"]["poll_after_unix"] = now
                item["pending"]["stream_retry_attempts"] = 0
                item["status"] = "restart_queued" if action == "restart" else "recovering_pending"
                item["status_detail"] = "Rechecking the existing ChatGPT response without resubmitting the prompt"
                event(state, profile_id, "pending_recovery_requested", item["status_detail"])
            elif action == "restart":
                item["status"] = "scheduled"
            elif not (state["owner_id"] == profile_id and item["job_id"]):
                item["status"] = "scheduled"

            if action == "restart":
                if item["job_id"] and item["pending"] is None:
                    event(state, profile_id, "job_wait_abandoned", item["job_id"])
                    item["job_id"] = None
                    item["next_job_poll_at_unix"] = None
                    item["job_poll_errors"] = 0
                item["request"] = "restart"
            elif action == "start" and state["owner_id"] != profile_id:
                item["request"] = "new"

            if action == "resume":
                item["poll_errors"] = 0
                item["job_poll_errors"] = 0

            if state["owner_id"] != profile_id:
                state["requested_profile_id"] = profile_id
                old_id = state["owner_id"]
                if old_id:
                    old = state["profiles"][old_id]
                    old["desired"] = "stopped"
                    if old["pending"] is not None:
                        # Polling is observational. A bounded explicit retry
                        # helps release an uncertain owner without a new send.
                        old["poll_errors"] = 0
                        old["pending"]["poll_after_unix"] = now
                    else:
                        old["status"] = "stopping"
                    old["status_detail"] = "Yielding transport after the existing response is resolved"
                    item["status"] = "waiting_owner"
                    item["status_detail"] = (
                        f"Waiting for {old_id} to release ChatGPT. "
                        "A pending or failed response must be resolved safely first.")
                    event(state, old_id, "handover_requested", profile_id)
                    event(state, profile_id, "waiting_owner", item["status_detail"])
        else:
            item["desired"] = "paused" if action == "pause" else "stopped"
            item["status_detail"] = ""
            if state.get("requested_profile_id") == profile_id:
                state["requested_profile_id"] = None
            item["status"] = "pausing" if state["owner_id"] == profile_id else (
                "paused" if action == "pause" else "idle")
            if action == "stop" and item["pending"] is not None:
                # Stop must be able to finish an old turn after the endpoint
                # returns, even when polling previously exhausted its retries.
                item["poll_errors"] = 0
                item["pending"]["poll_after_unix"] = now
            if state["owner_id"] != profile_id:
                item["request"] = None
        event(state, profile_id, action)
        return item["command_seq"] if action in {"start", "resume", "restart"} else None

    seq = change_state(mutate)
    if action in {"start", "resume", "restart"}:
        try:
            _ensure_runtime_services()
            _await_dispatch(profile_id, seq)
        except RuntimeError as exc:
            def failed(_config: dict, state: dict):
                item = state["profiles"].get(profile_id)
                if item is None:
                    return
                item["last_error"] = str(exc)[:2000]
                item["last_activity_at_unix"] = int(time.time())
                # Preserve a possibly submitted prompt, but report that this
                # command did not get a scheduler acknowledgement.
                item["status"] = "scheduler_unavailable"
                event(state, profile_id, "start_failed", item["last_error"])
            change_state(failed)
            raise
    return {"ok": True}



def request_park_unresolved(owner_id: str) -> dict:
    """Explicit user choice: preserve an unobservable old turn and unblock queue.

    The running bridge, not this control process, verifies current Desktop
    conditions and releases ownership between ticks under the transport lock.
    """
    def mutate(config: dict, state: dict):
        if state["owner_id"] != owner_id:
            raise ValueError("the selected profile is no longer the transport owner")
        item = state["profiles"][owner_id]
        if item["desired"] != "stopped" or item["pending"] is None:
            raise ValueError("only a stopped owner with an unresolved response can be parked")
        if item["parked_pending"]:
            raise ValueError("this response is already parked")
        if item["status"] != "waiting_desktop":
            raise ValueError(
                "the old response is not currently waiting on the ChatGPT Desktop view")
        waiting = state.get("requested_profile_id")
        target = next((p for p in config["profiles"]
                       if p["id"] == waiting and p["enabled"]), None)
        if not target or state["profiles"][waiting]["desired"] != "run":
            raise ValueError("start an enabled replacement profile first")
        if item["park_requested"]:
            raise ValueError("this parked-session request is already pending")
        item["park_requested"] = True
        item["status_detail"] = (
            "Checking Desktop before parking the unresolved turn. "
            "Its pending baseline and ChatGPT history will be kept.")
        event(state, owner_id, "park_requested",
              "Explicit confirmation to park the unresolved response and yield")
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
                item = state["profiles"][profile_id]
                if (field == "project_name" and not item.get("active_project_name")
                        and (state["owner_id"] == profile_id or item["pending"] is not None)):
                    # Migration-safe staging: capture the project of an
                    # already-open/pending chat before editing its next-chat target.
                    item["active_project_name"] = profile["project_name"]
                config["profiles"][index] = update_profile(
                    profile, {field: value}, confirm_delete=confirm_delete)
                if field == "enabled" and value is False:
                    item["desired"] = "stopped"
                    item["status"] = ("parked_unresolved" if item.get("parked_pending")
                                      else "stopping" if state["owner_id"] == profile_id
                                      else "disabled")
                elif field == "enabled" and value is True:
                    item["status"] = "parked_unresolved" if item.get("parked_pending") else "idle"
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


def remove_profile(profile_id: str, confirmed_unresolved: bool = False) -> dict:
    if confirmed_unresolved:
        # Only the single transport owner processes live removal between
        # ticks. Never delete a profile while its Desktop command is in flight.
        def request(config: dict, state: dict):
            if profile_id not in state["profiles"]:
                raise ValueError("profile not found")
            item = state["profiles"][profile_id]
            profile = next(p for p in config["profiles"] if p["id"] == profile_id)
            profile["enabled"] = False
            item["desired"] = "stopped"
            item["remove_requested"] = True
            item["status_detail"] = "Removal queued; a private recovery copy will be saved. ChatGPT history stays."
            if state.get("requested_profile_id") == profile_id:
                state["requested_profile_id"] = None
            event(state, profile_id, "removal_requested",
                  "Explicit confirmation to stop tracking and remove; ChatGPT history retained")
        change(request)
        # A stopped/failed bridge has no consumer. Process only this local
        # removal under the same transport lock, without starting ChatGPT.
        with (state_dir() / "chat-bridge.lock").open("a+") as handle:
            try:
                fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                return {"ok": True}
            from .daemon import _handle_removals
            config, state, _issues = read_snapshot()
            _handle_removals(config, state)
        return {"ok": True}

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
        if profile_id not in state["profiles"]:
            raise ValueError("profile not found")
        item = state["profiles"][profile_id]
        if item["pending"] is not None and not item.get("parked_pending"):
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
        parked = bool(state["profiles"][profile_id].get("parked_pending"))
        state["profiles"].pop(profile_id)
        event(state, profile_id, "removed",
              "ChatGPT history retained; parked recovery metadata discarded"
              if parked else "ChatGPT history retained")
    change(mutate)
    return {"ok": True}
