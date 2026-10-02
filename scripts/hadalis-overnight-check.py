#!/usr/bin/env python3
"""Bounded pre-bed validation of the two named managed profiles.

Read-only by default. --enable-safe-repair is an explicit, narrowly scoped
configuration change; it never Resumes, Restarts, submits prompts or edits
existing job/response receipts. No private IDs, chat text, logs or secrets.
"""
from __future__ import annotations

import argparse
import subprocess
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from automation.manager import control, store

TARGETS = ("MegaQML", "Wull Companion")
BLOCKED = {
    "session_changed", "session_conflict", "evidence_required",
    "connector_blocked", "recovery_required", "invalid_configuration",
    "thinking_unavailable", "scheduler_unavailable",
}
UNITS = ("hadalis-chat-bridge.service", "hadalis-worker.service",
         "hadalis-chatgpt.service")


def unit_check(unit, op):
    try:
        result = subprocess.run(
            ["systemctl", "--user", op, unit], stdin=subprocess.DEVNULL,
            capture_output=True, text=True, timeout=5, check=False)
        return result.returncode == 0 and result.stdout.strip() == (
            "active" if op == "is-active" else "enabled")
    except (OSError, subprocess.TimeoutExpired):
        return False


def run(enable=False):
    config, state, issues = store.read_snapshot()
    if issues:
        print("CONFIG=UNQUALIFIED")
        return 2
    profiles = []
    for name in TARGETS:
        matches = [p for p in config["profiles"] if p.get("name") == name]
        if len(matches) != 1:
            print("PROFILE_NAME_MATCH=UNQUALIFIED")
            return 2
        profiles.append(matches[0])
    # Never turn a stopped, paused or safety-blocked profile back on.
    for profile in profiles:
        item = state["profiles"][profile["id"]]
        if (not profile["enabled"] or profile["mode"] != "continuous" or
                profile.get("stop_on_done", False) or
                profile.get("iteration_limit", 0) != 0 or
                profile.get("prompt_limit", 0) != 0 or
                item["desired"] != "run" or item["status"] in BLOCKED):
            print("ENABLE_GUARD=BLOCKED")
            return 2

    if enable:
        for profile in profiles:
            if not profile.get("auto_protocol_recovery"):
                control.set_profile(profile["id"], "auto_protocol_recovery", "true")
        # Do not trust the pre-edit snapshot after concurrent scheduler steps.
        config, state, issues = store.read_snapshot()
        if issues:
            print("CONFIG_AFTER_EDIT=UNQUALIFIED")
            return 2
        profiles = [
            next(p for p in config["profiles"] if p["name"] == name)
            for name in TARGETS
        ]

    now = int(time.time())
    heartbeat = state.get("manager_heartbeat_at_unix")
    age = now - heartbeat if type(heartbeat) is int else None
    heartbeat_ok = age is not None and 0 <= age <= 90
    print("HEARTBEAT=" + ("PASS" if heartbeat_ok else "STALE_OR_MISSING"))
    service_ok = True
    for unit in UNITS:
        short = unit.replace("hadalis-", "").replace(".service", "").upper().replace("-", "_")
        active = unit_check(unit, "is-active")
        enabled = unit_check(unit, "is-enabled")
        print(short + "_ACTIVE=" + ("PASS" if active else "FAIL"))
        print(short + "_ENABLED=" + ("PASS" if enabled else "CHECK"))
        service_ok &= active

    cooldown = state.get("transport_retry_at_unix", 0)
    print("SHARED_RATE_COOLDOWN_SECONDS=" +
          str(max(0, cooldown - now) if type(cooldown) is int else "UNKNOWN"))

    identities = []
    profiles_ok = True
    for profile in profiles:
        key = "MEGAQML" if profile["name"] == "MegaQML" else "WULL"
        item = state["profiles"][profile["id"]]
        session = item.get("session") or {}
        if session.get("conversation_id"):
            identities.append(session["conversation_id"])
        pending = item.get("pending") or {}
        attempts = item.get("protocol_repair_attempts", 0)
        is_running = item.get("desired") == "run" and item.get("status") not in BLOCKED
        auto = profile.get("auto_protocol_recovery") is True
        unlimited = (not profile.get("stop_on_done", False) and
                     profile.get("iteration_limit", 0) == 0 and
                     profile.get("prompt_limit", 0) == 0)
        next_time = pending.get("poll_after_unix") if pending else item.get("next_run_at_unix")
        print(key + "_RUNNING=" + ("PASS" if is_running else "FAIL"))
        print(key + "_UNBOUNDED_CONTINUOUS=" + ("PASS" if unlimited else "REVIEW_LIMITS"))
        print(key + "_AUTO_PROTOCOL_REPAIR=" + ("ON" if auto else "OFF"))
        print(key + "_STATUS=" + (item["status"] if item.get("status") in (
            "thinking", "continuing", "recovering_protocol", "transport_rate_limited",
            "transport_unavailable", "waiting_result", "rotating", "starting",
            "scheduled", "recovering_generation", "response_unavailable",
            "stream_failed") else "REVIEW"))
        print(key + "_PENDING=" + ("YES" if pending else "NO"))
        print(key + "_REPAIR_ATTEMPTS=" + (
            str(attempts) if type(attempts) is int and 0 <= attempts <= 2 else "UNQUALIFIED"))
        print(key + "_NEXT_ACTION_SECONDS=" + (
            str(max(0, next_time-now)) if type(next_time) is int else "SCHEDULER_CONTROLLED"))
        if attempts == 2:
            print(key + "_REPAIR_BUDGET=EXHAUSTION_RISK")
        profiles_ok &= is_running and auto and unlimited and type(attempts) is int and 0 <= attempts <= 2
    isolated = len(identities) == len(set(identities))
    print("CONVERSATION_ISOLATION=" + ("PASS" if isolated else "FAIL"))
    print("KEEP_AWAKE=" + "CONFIGURE_OS_POWER_SETTINGS")
    passed = heartbeat_ok and service_ok and profiles_ok and isolated
    print("RESULT=" + ("READY_WITH_EXTERNAL_DEPENDENCIES" if passed else "NEEDS_ATTENTION"))
    # Healthy services and safe self-retry cannot guarantee ChatGPT quota,
    # Internet, a still-running server response, or an awake desktop.
    return 0 if passed else 2


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--enable-safe-repair", action="store_true",
                        help="Explicitly enable only the two named profiles")
    args = parser.parse_args()
    raise SystemExit(run(enable=args.enable_safe_repair))
