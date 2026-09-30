from __future__ import annotations

import argparse
import fcntl
import json
import os
from pathlib import Path
import subprocess
import sys
import time

from automation.chat_bridge.protocol import DirectiveKind, parse_loop_directive
from automation.manager.model import choose_profile, effective_prompt, limit_decision
from automation.manager.store import (archive_removed_profile, change, change_state,
                                      event, read_snapshot, state_dir, state_path)

ROOT = Path(__file__).resolve().parents[2]
DESKTOP_CLI = ROOT / "automation/chat_bridge/desktop_cli.mjs"
RESULTS = "automation/results"
POLL_SECONDS = 2


class DesktopBusy(RuntimeError):
    """The current owned ChatGPT chat has not finished generating."""


class DesktopViewChanged(RuntimeError):
    """Desktop is showing a different chat; the pending response is untouched."""


def desktop_command(command: str, *args: str, prompt: str | None = None,
                    project_name: str | None = None) -> dict:
    environment = os.environ.copy()
    if project_name is not None:
        environment["HADALIS_CHATGPT_PROJECT"] = project_name
    result = subprocess.run(
        ["node", str(DESKTOP_CLI), command, *args], cwd=ROOT,
        input=prompt, env=environment, capture_output=True, text=True,
        timeout=40, check=False,
    )
    if result.returncode:
        detail = (result.stderr or result.stdout).strip()[:600]
        if detail.startswith("HADALIS_DESKTOP_BUSY: "):
            raise DesktopBusy(detail.removeprefix("HADALIS_DESKTOP_BUSY: "))
        if detail.startswith("HADALIS_DESKTOP_VIEW_CHANGED: "):
            raise DesktopViewChanged(detail.removeprefix("HADALIS_DESKTOP_VIEW_CHANGED: "))
        raise RuntimeError(detail)
    try:
        payload = json.loads(result.stdout)
    except json.JSONDecodeError as exc:
        raise RuntimeError("desktop transport returned invalid JSON") from exc
    if not isinstance(payload, dict):
        raise RuntimeError("desktop transport returned invalid object")
    return payload


def job_result(job_id: str) -> dict | None:
    fetched = subprocess.run(["git", "fetch", "origin", "dev"], cwd=ROOT,
                             capture_output=True, text=True, timeout=120, check=False)
    if fetched.returncode:
        raise RuntimeError("could not fetch current dev for local job")
    shown = subprocess.run(["git", "show", f"origin/dev:{RESULTS}/{job_id}.json"],
                           cwd=ROOT, capture_output=True, text=True, timeout=30, check=False)
    if shown.returncode:
        return None
    payload = json.loads(shown.stdout)
    if not isinstance(payload, dict) or payload.get("job") != job_id:
        raise RuntimeError("local job result does not match requested job")
    return payload


def _profile(config: dict, owner: str) -> dict:
    return next(profile for profile in config["profiles"] if profile["id"] == owner)


def _transport_project_name(config: dict, state: dict, owner: str) -> str:
    return state["profiles"][owner].get("active_project_name") or _profile(config, owner)["project_name"]


def _release(state: dict, owner: str, now: int, reason: str) -> None:
    item = state["profiles"][owner]
    state["owner_id"] = None
    item["pending"] = None
    item["request"] = None
    item["job_id"] = None
    item["status"] = reason
    item["status_detail"] = ""
    item["active_project_name"] = ""
    item["last_activity_at_unix"] = now
    event(state, owner, reason)


def _claim(config: dict, state: dict, now: int) -> str | None:
    owner = choose_profile(config, state, now)
    # One explicit user request may take priority over default continuous mode
    # only after any previous owner safely releases the ChatGPT transport.
    requested = state.get("requested_profile_id")
    if state["owner_id"] is None and requested:
        preferred = next((p for p in config["profiles"]
                          if p["id"] == requested and p["enabled"]), None)
        item = state["profiles"].get(requested)
        if preferred and item and item["desired"] == "run":
            if (item.get("next_run_at_unix") or 0) <= now:
                owner = requested
        else:
            state["requested_profile_id"] = None
    if owner is None:
        return None
    if state["owner_id"] is None:
        state["owner_id"] = owner
        if state.get("requested_profile_id") == owner:
            state["requested_profile_id"] = None
        item = state["profiles"][owner]
        item["status_detail"] = ""
        item["active_project_name"] = ""
        item["status"] = "starting"
        item["started_at_unix"] = now
        item["chat_started_at_unix"] = None
        item["chat_iterations"] = 0
        item["run_start_iterations"] = item["iterations"]
        item["run_start_prompts"] = item["prompts_sent"]
        item["request"] = "initial"
        item["last_run_at_unix"] = now
        item["next_run_at_unix"] = None
        event(state, owner, "started")
    return owner


def _stop_or_pause(config: dict, state: dict, owner: str, now: int) -> bool:
    item = state["profiles"][owner]
    profile = _profile(config, owner)
    if item["pending"] is not None:
        return False  # Completion must be observed before yielding the composer.
    if item["desired"] == "stopped" or not profile["enabled"]:
        _release(state, owner, now, "disabled" if not profile["enabled"] else "idle")
        return True
    if item["desired"] == "paused":
        item["status"] = "paused"  # Retain transport ownership for safe resume.
        return True
    return False


def _new_chat(owner: str, now: int, *, kind: str, project_name: str) -> None:
    # A newly claimed owner has no chat to protect and can leave an unrelated
    # active chat. An owned chat must pass the idle guard before rotation.
    _config, state, _issues = read_snapshot()
    unowned_previous = state["profiles"][owner]["chat_started_at_unix"] is None
    desktop_command("new-chat", *("--unowned-previous-chat",) if unowned_previous else (),
                    project_name=project_name)

    def record(_config: dict, state: dict):
        item = state["profiles"][owner]
        if item["request"] == "restart":
            item["started_at_unix"] = now
            item["run_start_iterations"] = item["iterations"]
            item["run_start_prompts"] = item["prompts_sent"]
        item["chat_started_at_unix"] = now
        item["active_project_name"] = project_name
        item["chat_iterations"] = 0
        item["request"] = kind
        item["next_run_at_unix"] = None
        item["last_error"] = ""
        item["status"] = "rotating" if kind == "rotation" else "starting"
        event(state, owner, "chat_rotated" if kind == "rotation" else "chat_opened")
    change_state(record)


def _submit(config: dict, state: dict, owner: str, now: int) -> None:
    item = state["profiles"][owner]
    kind = item.get("request") or "continuation"
    profile = _profile(config, owner)
    if kind in {"initial", "rotation", "restart", "new"}:
        _new_chat(owner, now, kind="rotation" if kind == "rotation" else "initial",
                  project_name=profile["project_name"])
        config, state, _ = read_snapshot()
        item = state["profiles"][owner]
        kind = item["request"]
        profile = _profile(config, owner)
    transport_project = _transport_project_name(config, state, owner)
    baseline = desktop_command("managed-baseline", project_name=transport_project)
    count = baseline.get("responseActionCount")
    if type(count) is not int or count < 0:
        raise RuntimeError("desktop baseline is invalid")

    def prepare(_config: dict, current: dict):
        current_item = current["profiles"][owner]
        current_item["pending"] = {"response_action_count": count,
                                   "kind": kind, "prepared_at_unix": now,
                                   "poll_after_unix": now + POLL_SECONDS,
                                   "counted": False}
        current_item["status"] = "thinking"
        current_item["status_detail"] = ""
        current_item["last_activity_at_unix"] = now
        event(current, owner, "prompt_prepared", kind)
    change_state(prepare)
    prompt = effective_prompt(profile, kind)
    try:
        desktop_command("managed-submit", str(count), prompt=prompt,
                        project_name=transport_project)
    except (DesktopBusy, DesktopViewChanged):
        # The Desktop CLI raises this only before filling or sending. Remove
        # the pre-send baseline so the scheduler can safely retry later.
        change_state(lambda _config, current: current["profiles"][owner].update(
            {"pending": None}))
        raise
    except Exception as exc:
        # The submission may have reached ChatGPT before the transport failed.
        # Keep the pending baseline and poll for a fresh response; never resend.
        change_state(lambda _config, current: _submission_uncertain(current, owner, now, exc))
        return

    def accepted(_config: dict, current: dict):
        current_item = current["profiles"][owner]
        if current_item["pending"] and not current_item["pending"]["counted"]:
            current_item["prompts_sent"] += 1
            current_item["pending"]["counted"] = True
        current_item["status"] = "thinking"
        event(current, owner, "prompt_submitted", kind)
    change_state(accepted)


def _submission_uncertain(state: dict, owner: str, now: int, exc: Exception) -> None:
    item = state["profiles"][owner]
    item["status"] = "transport_unavailable"
    item["last_error"] = str(exc)[:2000]
    item["failures"] += 1
    item["last_activity_at_unix"] = now
    event(state, owner, "submission_uncertain", item["last_error"])


def _poll(config: dict, state: dict, owner: str, now: int) -> None:
    item = state["profiles"][owner]
    pending = item["pending"]
    if pending is None or now < pending.get("poll_after_unix", 0):
        return
    if item["desired"] == "paused" and item["status"] == "stream_failed":
        return  # Keep the failed turn for an explicit recovery action.
    if item["poll_errors"] > _profile(config, owner)["max_poll_errors"]:
        return  # Needs explicit Start/Resume; keep uncertain pending baseline.
    transport_project = _transport_project_name(config, state, owner)
    try:
        result = desktop_command("managed-poll", str(pending["response_action_count"]),
                                 project_name=transport_project)
        if result.get("streamError"):
            if pending.get("stream_retry_attempts", 0) >= 1:
                def exhausted(_config: dict, current: dict):
                    current_item = current["profiles"][owner]
                    current_item["desired"] = "paused"
                    current_item["status"] = "stream_failed"
                    current_item["last_error"] = "ChatGPT response stream failed after Retry"
                    current_item["pending"]["poll_after_unix"] = now + 3600
                    event(current, owner, "stream_retry_exhausted", current_item["last_error"])
                change_state(exhausted)
                return
            def preparing_retry(_config: dict, current: dict):
                current_item = current["profiles"][owner]
                current_item["pending"]["stream_retry_attempts"] = 1
                current_item["pending"]["poll_after_unix"] = now + max(
                    POLL_SECONDS, _profile(_config, owner)["retry_delay_seconds"])
                current_item["status"] = "retrying_stream"
                event(current, owner, "stream_retry_started")
            change_state(preparing_retry)
            desktop_command("managed-retry", str(pending["response_action_count"]),
                            project_name=transport_project)
            return
        if not result.get("completed"):
            def waiting(_config: dict, current: dict):
                current_item = current["profiles"][owner]
                current_item["pending"]["poll_after_unix"] = now + POLL_SECONDS
                current_item["poll_errors"] = 0
                current_item["last_error"] = ""
                if current_item["desired"] == "run":
                    current_item["status"] = "thinking"
            change_state(waiting)
            return
        response = result.get("response", {})
        directive = parse_loop_directive(response.get("text", ""))
    except DesktopViewChanged as exc:
        def view_changed(current_config: dict, current: dict):
            current_item = current["profiles"][owner]
            if current_item["status"] != "waiting_desktop":
                event(current, owner, "desktop_view_changed", str(exc))
            current_item["pending"]["poll_after_unix"] = now + min(
                _profile(current_config, owner)["retry_delay_seconds"], 60)
            current_item["last_error"] = str(exc)[:2000]
            current_item["status"] = "waiting_desktop"
        change_state(view_changed)
        return
    except Exception as exc:
        def failed(current_config: dict, current: dict):
            current_item = current["profiles"][owner]
            current_item["poll_errors"] += 1
            current_item["failures"] += 1
            delay = min(_profile(current_config, owner)["retry_delay_seconds"]
                        * (2 ** min(current_item["poll_errors"] - 1, 4)), 3600)
            current_item["pending"]["poll_after_unix"] = now + delay
            current_item["last_error"] = str(exc)[:2000]
            current_item["status"] = "transport_unavailable"
            if (current_item["desired"] == "run" and
                    current_item["poll_errors"] > _profile(current_config, owner)["max_poll_errors"]):
                current_item["desired"] = "paused"
            event(current, owner, "stream_poll_failure", current_item["last_error"])
        change_state(failed)
        return

    def complete(current_config: dict, current: dict):
        current_item = current["profiles"][owner]
        if current_item["pending"] is None:
            return
        if not current_item["pending"].get("counted"):
            current_item["prompts_sent"] += 1
        current_item["pending"] = None
        current_item["iterations"] += 1
        current_item["chat_iterations"] += 1
        current_item["poll_errors"] = 0
        current_item["last_error"] = ""
        current_item["last_activity_at_unix"] = now
        current_item["last_success"] = directive.kind.value
        current_item["loop_state"] = directive.kind.value.lower()
        event(current, owner, "response", directive.kind.value)
        if directive.kind is DirectiveKind.WAIT_RESULT and current_item["request"] != "restart":
            current_item["job_id"] = directive.argument
            current_item["next_job_poll_at_unix"] = now
            current_item["status"] = "waiting_result"
            event(current, owner, "wait_result", directive.argument or "")
            return
        if current_item["request"] == "restart" and current_item["desired"] == "run":
            # The completion belongs to the pre-restart prompt. Record it,
            # but do not let its old directive cancel an explicit safe restart.
            current_item["status"] = "rotating"
            current_item["status_detail"] = ""
            return
        if directive.kind is DirectiveKind.CONNECTOR_BLOCKED:
            current_item["desired"] = "paused"
            current_item["last_error"] = "GitHub connector needs attention"
            _release(current, owner, now, "connector_blocked")
            return
        profile = _profile(current_config, owner)
        if _stop_or_pause(current_config, current, owner, now):
            return
        decision = limit_decision(profile, current_item, now)
        if decision == "stop":
            current_item["desired"] = "stopped"
            _release(current, owner, now, "completed")
            return
        if decision == "pause":
            current_item["desired"] = "paused"
            current_item["status"] = "paused"
            event(current, owner, "limit_paused")
            return
        if decision == "rotate" or directive.kind is DirectiveKind.ROTATE:
            current_item["request"] = "rotation"
            if decision == "rotate" and profile["mode"] == "duration":
                current_item["started_at_unix"] = now
            current_item["status"] = "rotating"
            return
        if directive.kind is DirectiveKind.DONE and profile["mode"] != "continuous":
            current_item["desired"] = "stopped"
            _release(current, owner, now, "completed")
            return
        if profile["mode"] == "interval" and (
                current_item["iterations"] > current_item.get("run_start_iterations", 0)):
            _release(current, owner, now, "scheduled")
            current_item["desired"] = "run"
            current_item["next_run_at_unix"] = now + profile["interval_seconds"]
            return
        current_item["request"] = "continuation"
        current_item["status"] = "continuing"
    change_state(complete)


def _wait_result(config: dict, state: dict, owner: str, now: int) -> None:
    item = state["profiles"][owner]
    job_id = item["job_id"]
    if job_id is None:
        return
    if now < (item.get("next_job_poll_at_unix") or 0):
        return
    if item["job_poll_errors"] > _profile(config, owner)["max_failures"]:
        return
    try:
        payload = job_result(job_id)
    except Exception as exc:
        change_state(lambda current_config, current: _job_poll_error(current_config, current, owner, now, exc))
        return
    if payload is None:
        change_state(lambda _config, current: current["profiles"][owner].update(
            {"next_job_poll_at_unix": now + 10, "status": "waiting_result"}))
        return
    def ready(_config: dict, current: dict):
        current_item = current["profiles"][owner]
        current_item["last_job_id"] = job_id
        current_item["last_result"] = str(payload.get("status", "unknown"))
        current_item["job_id"] = None
        current_item["job_poll_errors"] = 0
        current_item["next_job_poll_at_unix"] = None
        current_item["last_activity_at_unix"] = now
        current_item["request"] = "continuation"
        current_item["status"] = "continuing"
        event(current, owner, "job_result", job_id + " " + current_item["last_result"])
    change_state(ready)


def _job_poll_error(config: dict, state: dict, owner: str, now: int, exc: Exception) -> None:
    item = state["profiles"][owner]
    item["job_poll_errors"] += 1
    item["failures"] += 1
    item["next_job_poll_at_unix"] = now + min(
        _profile(config, owner)["retry_delay_seconds"] * 2 ** min(item["job_poll_errors"], 4), 3600)
    item["last_error"] = str(exc)[:2000]
    item["status"] = "transport_unavailable"
    if item["job_poll_errors"] > _profile(config, owner)["max_failures"]:
        item["desired"] = "paused"
    event(state, owner, "result_poll_failure", item["last_error"])


def _handle_park_request(config: dict, state: dict, owner: str, now: int) -> bool:
    """Park an explicitly confirmed, unobservable response without discarding it."""
    item = state["profiles"][owner]
    if not item.get("park_requested"):
        return False
    pending = item.get("pending")
    if item["desired"] != "stopped" or pending is None:
        def invalid(_config: dict, current: dict):
            current_item = current["profiles"][owner]
            current_item["park_requested"] = False
            current_item["last_error"] = "Park request became invalid before Desktop verification"
            event(current, owner, "park_rejected", current_item["last_error"])
        change_state(invalid)
        return True
    if now < pending.get("park_check_after_unix", 0):
        return True

    try:
        check = desktop_command(
            "handover-check", project_name=_transport_project_name(config, state, owner))
    except Exception as exc:
        def failed(_config: dict, current: dict):
            current_item = current["profiles"][owner]
            current_item["park_requested"] = False
            current_item["last_error"] = ("Could not safely verify the current Desktop view: "
                                          + str(exc))[:2000]
            current_item["status_detail"] = ""
            event(current, owner, "park_rejected", current_item["last_error"])
        change_state(failed)
        return True

    if check.get("projectGuardVisible", 0) != 0:
        def recover(_config: dict, current: dict):
            current_item = current["profiles"][owner]
            current_item["park_requested"] = False
            current_item["last_error"] = ""
            current_item["status"] = "recovering_pending"
            current_item["status_detail"] = "Original project is visible again; rechecking the pending response"
            current_item["pending"]["poll_after_unix"] = now
            event(current, owner, "park_cancelled_project_visible")
        change_state(recover)
        return True

    if check.get("generationActive") or check.get("draftPresent") or not check.get("composerReady"):
        detail = ("Current ChatGPT view is not idle enough to park safely; "
                  "finish its generation or clear its draft and retry")
        def busy(_config: dict, current: dict):
            current_item = current["profiles"][owner]
            current_item["park_requested"] = False
            current_item["last_error"] = detail
            current_item["status_detail"] = ""
            event(current, owner, "park_rejected", detail)
        change_state(busy)
        return True

    def park(_config: dict, current: dict):
        current_item = current["profiles"][owner]
        if current["owner_id"] != owner or not current_item.get("park_requested"):
            return
        if current_item["pending"] is None or current_item["desired"] != "stopped":
            return
        target_id = current.get("requested_profile_id")
        target = current["profiles"].get(target_id) if target_id else None
        if target is None or target["desired"] != "run":
            current_item["park_requested"] = False
            current_item["last_error"] = "Replacement profile is no longer queued"
            event(current, owner, "park_rejected", current_item["last_error"])
            return
        current["owner_id"] = None
        current_item["park_requested"] = False
        current_item["parked_pending"] = True
        current_item["status"] = "parked_unresolved"
        current_item["status_detail"] = (
            "Unresolved response baseline preserved; automatic recovery is disabled "
            "until it is manually reconciled.")
        current_item["last_error"] = ""
        current_item["last_activity_at_unix"] = now
        target["status"] = "scheduled"
        target["status_detail"] = ""
        target["next_run_at_unix"] = now
        event(current, owner, "pending_parked",
              "Pending response preserved; transport yielded to queued profile")
    change_state(park)
    return True


def _handle_removals(config: dict, state: dict) -> bool:
    ids = [p["id"] for p in config["profiles"]
           if state["profiles"][p["id"]].get("remove_requested")]
    if not ids:
        return False

    def remove(current_config: dict, current: dict):
        for profile_id in ids:
            item = current["profiles"].get(profile_id)
            if not item or not item.get("remove_requested"):
                continue
            profile = _profile(current_config, profile_id)
            # Archive first: a failed write must leave ownership and pending
            # state intact. This operation never navigates or cancels a chat.
            path = archive_removed_profile(profile, item)
            current_config["profiles"] = [p for p in current_config["profiles"]
                                          if p["id"] != profile_id]
            current["profiles"].pop(profile_id)
            if current["owner_id"] == profile_id:
                current["owner_id"] = None
            if current.get("requested_profile_id") == profile_id:
                current["requested_profile_id"] = None
            event(current, profile_id, "removed",
                  f"ChatGPT history retained; recovery copy: {path}")
    change(remove)
    return True


def _heartbeat(state: dict, now: int) -> None:
    state["manager_heartbeat_at_unix"] = now
    state["command_ack_seq"] = state["command_seq"]
    for profile_id, item in state["profiles"].items():
        if item["desired"] != "run" or item["status"] != "scheduler_unavailable":
            continue
        if state["owner_id"] == profile_id:
            item["status"] = "recovering_pending" if item["pending"] is not None else "starting"
        elif state["owner_id"] is not None:
            item["status"] = "waiting_owner"
        else:
            item["status"] = "scheduled"
        item["last_error"] = ""
        event(state, profile_id, "scheduler_recovered")


def _configuration_problem(state: dict, issues: list[str]) -> None:
    detail = ("Invalid Automation configuration: " + "; ".join(issues))[:2000]
    for profile_id, item in state["profiles"].items():
        if item["desired"] != "run":
            continue
        if item["status"] != "invalid_configuration" or item["last_error"] != detail:
            item["status"] = "invalid_configuration"
            item["last_error"] = detail
            item["last_activity_at_unix"] = int(time.time())
            event(state, profile_id, "invalid_configuration", detail)


def _fatal_scheduler_error(state: dict, exc: Exception) -> None:
    detail = (type(exc).__name__ + ": " + str(exc))[:2000]
    owner = state["owner_id"]
    if owner and owner in state["profiles"]:
        item = state["profiles"][owner]
        item["status"] = "scheduler_unavailable"
        item["last_error"] = detail
        item["last_activity_at_unix"] = int(time.time())
    event(state, owner, "scheduler_crashed", detail)


def tick(now: int | None = None) -> None:
    now = int(time.time()) if now is None else now
    config, state, issues = read_snapshot()
    if (state.get("manager_heartbeat_at_unix") is None or
            now - state["manager_heartbeat_at_unix"] >= 10 or
            state.get("command_seq", 0) > state.get("command_ack_seq", 0) or
            any(item["status"] == "scheduler_unavailable"
                for item in state["profiles"].values())):
        change_state(lambda _config, current: _heartbeat(current, now))
        config, state, issues = read_snapshot()
    if issues:
        change_state(lambda _config, current: _configuration_problem(current, issues))
        return  # Do not execute malformed profiles.
    if _handle_removals(config, state):
        return
    owner = state["owner_id"]
    if owner is not None and state["profiles"][owner].get("park_requested"):
        _handle_park_request(config, state, owner, now)
        return
    if owner is None:
        owner = change_state(lambda c, s: _claim(c, s, now))
        if owner is None:
            return
        config, state, _issues = read_snapshot()
    item = state["profiles"][owner]
    if item["pending"] is not None:
        _poll(config, state, owner, now)
        return
    if change_state(lambda c, s: _stop_or_pause(c, s, owner, now)):
        return
    config, state, _issues = read_snapshot()
    item = state["profiles"][owner]
    if item["job_id"]:
        _wait_result(config, state, owner, now)
        return
    if now < (item.get("next_run_at_unix") or 0):
        return
    try:
        _submit(config, state, owner, now)
    except (DesktopBusy, DesktopViewChanged) as exc:
        def waiting(current_config: dict, current: dict):
            current_item = current["profiles"][owner]
            if current_item["status"] != "waiting_desktop":
                event(current, owner, "desktop_view_changed" if isinstance(exc, DesktopViewChanged)
                      else "desktop_busy", str(exc))
            current_item["last_error"] = str(exc)[:2000]
            current_item["status"] = "waiting_desktop"
            current_item["next_run_at_unix"] = now + min(
                _profile(current_config, owner)["retry_delay_seconds"], 60)
        change_state(waiting)
    except Exception as exc:
        def failed(_config: dict, current: dict):
            current_item = current["profiles"][owner]
            current_item["last_error"] = str(exc)[:2000]
            current_item["failures"] += 1
            current_item["status"] = "transport_unavailable"
            current_item["desired"] = "paused"
            event(current, owner, "transport_failure", current_item["last_error"])
        change_state(failed)


def main() -> int:
    parser = argparse.ArgumentParser(description="Single-owner Hadalis automation scheduler")
    parser.add_argument("--once", action="store_true", help="perform one deterministic scheduler tick")
    parser.add_argument("--reset-state", action="store_true", help="clear bridge session state while holding the transport lock")
    args = parser.parse_args()
    lock_path = state_dir() / "chat-bridge.lock"
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    with lock_path.open("w") as handle:
        try:
            fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as exc:
            raise SystemExit("another Hadalis chat bridge owns the ChatGPT transport") from exc
        if args.reset_state:
            state_path().unlink(missing_ok=True)
            (state_dir() / "chat-bridge.json").unlink(missing_ok=True)
            return 0
        while True:
            try:
                tick()
            except Exception as exc:
                # Preserve fatal errors in Activity before systemd restarts us.
                try:
                    change_state(lambda _config, state: _fatal_scheduler_error(state, exc))
                except Exception as record_error:
                    print(f"could not record scheduler failure: {record_error}", file=sys.stderr)
                raise
            if args.once:
                return 0
            time.sleep(POLL_SECONDS)


if __name__ == "__main__":
    raise SystemExit(main())
