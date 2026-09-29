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
from automation.manager.store import change_state, event, read_snapshot, state_dir

ROOT = Path(__file__).resolve().parents[2]
DESKTOP_CLI = ROOT / "automation/chat_bridge/desktop_cli.mjs"
RESULTS = "automation/results"
POLL_SECONDS = 2


def desktop_command(command: str, *args: str, prompt: str | None = None) -> dict:
    result = subprocess.run(
        ["node", str(DESKTOP_CLI), command, *args], cwd=ROOT,
        input=prompt, capture_output=True, text=True, timeout=40, check=False,
    )
    if result.returncode:
        raise RuntimeError((result.stderr or result.stdout).strip()[:600])
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


def _release(state: dict, owner: str, now: int, reason: str) -> None:
    item = state["profiles"][owner]
    state["owner_id"] = None
    item["pending"] = None
    item["request"] = None
    item["job_id"] = None
    item["status"] = reason
    item["last_activity_at_unix"] = now
    event(state, owner, reason)


def _claim(config: dict, state: dict, now: int) -> str | None:
    owner = choose_profile(config, state, now)
    if owner is None:
        return None
    if state["owner_id"] is None:
        state["owner_id"] = owner
        item = state["profiles"][owner]
        item["status"] = "starting"
        item["started_at_unix"] = now
        item["chat_started_at_unix"] = None
        item["chat_iterations"] = 0
        item["run_start_iterations"] = item["iterations"]
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


def _new_chat(owner: str, now: int, *, kind: str) -> None:
    # The desktop driver checks the old composer/generation before opening a
    # new chat. A failed guard cannot displace the current owner's session.
    desktop_command("new-chat")

    def record(_config: dict, state: dict):
        item = state["profiles"][owner]
        item["chat_started_at_unix"] = now
        item["chat_iterations"] = 0
        item["request"] = kind
        item["status"] = "rotating" if kind == "rotation" else "starting"
        event(state, owner, "chat_rotated" if kind == "rotation" else "chat_opened")
    change_state(record)


def _submit(config: dict, state: dict, owner: str, now: int) -> None:
    item = state["profiles"][owner]
    kind = item.get("request") or "continuation"
    if kind in {"initial", "rotation", "restart", "new"}:
        _new_chat(owner, now, kind="rotation" if kind == "rotation" else "initial")
        config, state, _ = read_snapshot()
        item = state["profiles"][owner]
        kind = item["request"]
    baseline = desktop_command("managed-baseline")
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
        current_item["last_activity_at_unix"] = now
        event(current, owner, "prompt_prepared", kind)
    change_state(prepare)
    profile = _profile(config, owner)
    prompt = effective_prompt(profile, kind)
    try:
        desktop_command("managed-submit", str(count), prompt=prompt)
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
    item["last_error"] = str(exc)[:500]
    item["last_activity_at_unix"] = now
    event(state, owner, "submission_uncertain", item["last_error"])


def _poll(config: dict, state: dict, owner: str, now: int) -> None:
    item = state["profiles"][owner]
    pending = item["pending"]
    if pending is None or now < pending.get("poll_after_unix", 0):
        return
    if item["poll_errors"] > _profile(config, owner)["max_poll_errors"]:
        return  # Needs explicit resume; owner and pending baseline stay intact.
    try:
        result = desktop_command("managed-poll", str(pending["response_action_count"]))
        if not result.get("completed"):
            def waiting(_config: dict, current: dict):
                current_item = current["profiles"][owner]
                current_item["pending"]["poll_after_unix"] = now + POLL_SECONDS
                if current_item["desired"] == "run":
                    current_item["status"] = "thinking"
            change_state(waiting)
            return
        response = result.get("response", {})
        directive = parse_loop_directive(response.get("text", ""))
    except Exception as exc:
        def failed(current_config: dict, current: dict):
            current_item = current["profiles"][owner]
            current_item["poll_errors"] += 1
            delay = min(_profile(current_config, owner)["retry_delay_seconds"]
                        * (2 ** min(current_item["poll_errors"] - 1, 4)), 3600)
            current_item["pending"]["poll_after_unix"] = now + delay
            current_item["last_error"] = str(exc)[:500]
            current_item["status"] = "transport_unavailable"
            if current_item["poll_errors"] > _profile(current_config, owner)["max_poll_errors"]:
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
        if directive.kind is DirectiveKind.WAIT_RESULT:
            current_item["job_id"] = directive.argument
            current_item["next_job_poll_at_unix"] = now
            current_item["status"] = "waiting_result"
            event(current, owner, "wait_result", directive.argument or "")
            return
        if directive.kind is DirectiveKind.CONNECTOR_BLOCKED:
            current_item["desired"] = "paused"
            current_item["last_error"] = "GitHub connector needs attention"
            _release(current, owner, now, "connector_blocked")
            return
        profile = _profile(current_config, owner)
        if _stop_or_pause(current_config, current, owner, now):
            return
        if current_item["request"] == "restart":
            current_item["status"] = "rotating"
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
        change_state(lambda _config, current: _job_poll_error(current, owner, exc))
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


def _job_poll_error(state: dict, owner: str, exc: Exception) -> None:
    item = state["profiles"][owner]
    item["job_poll_errors"] += 1
    item["next_job_poll_at_unix"] = int(time.time()) + min(10 * 2 ** min(item["job_poll_errors"], 5), 300)
    item["last_error"] = str(exc)[:500]
    item["status"] = "transport_unavailable"
    if item["job_poll_errors"] > 3:
        item["desired"] = "paused"
    event(state, owner, "result_poll_failure", item["last_error"])


def tick(now: int | None = None) -> None:
    now = int(time.time()) if now is None else now
    config, state, issues = read_snapshot()
    if issues:
        return  # Invalid/stale definitions require repair; do not guess.
    owner = state["owner_id"]
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
    try:
        _submit(config, state, owner, now)
    except Exception as exc:
        def failed(_config: dict, current: dict):
            current_item = current["profiles"][owner]
            current_item["last_error"] = str(exc)[:500]
            current_item["status"] = "transport_unavailable"
            current_item["desired"] = "paused"
            event(current, owner, "transport_failure", current_item["last_error"])
        change_state(failed)


def main() -> int:
    parser = argparse.ArgumentParser(description="Single-owner Hadalis automation scheduler")
    parser.add_argument("--once", action="store_true", help="perform one deterministic scheduler tick")
    args = parser.parse_args()
    lock_path = state_dir() / "chat-bridge.lock"
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    with lock_path.open("w") as handle:
        try:
            fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as exc:
            raise SystemExit("another Hadalis chat bridge owns the ChatGPT transport") from exc
        while True:
            tick()
            if args.once:
                return 0
            time.sleep(POLL_SECONDS)


if __name__ == "__main__":
    raise SystemExit(main())
