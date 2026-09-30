#!/usr/bin/env python3
"""Regression for real-world split checkouts and stalled pending ChatGPT replies.

Start re-observes a previously submitted response; it never blindly sends again.
Each mode's explicit Start outranks an already-scheduled continuous profile.
"""
from __future__ import annotations

import os
from pathlib import Path
import sys
import tempfile
import time
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from automation.manager import control, daemon, store  # noqa: E402


def active_services():
    return {
        key: {
            "state": "active", "detail": "running", "result": "success",
            "working_directory": "/home/example/Hadalis",
            "exec_start": "/usr/bin/python3 -m automation.manager.daemon",
        }
        for key in control.UNITS
    }


def desktop_for_initial(commands):
    def reply(command, *args, prompt=None, project_name=None):
        commands.append(command)
        if command == "new-chat":
            return {}
        if command == "managed-baseline":
            return {"responseActionCount": 0}
        if command == "managed-submit":
            assert prompt is not None and "[@GitHub]" in prompt
            return {"submitted": True}
        raise AssertionError(command)
    return reply


def main():
    # A separate shell install is NOT an outdated source checkout. A healthy
    # heartbeat and active services are the authority, not equal cwd strings.
    now = int(time.time())
    with tempfile.TemporaryDirectory() as tmp:
        with patch.dict(os.environ, {"XDG_CONFIG_HOME": tmp + "/config",
                                     "XDG_STATE_HOME": tmp + "/state"}):
            def heartbeat(_config, state):
                state["manager_heartbeat_at_unix"] = now
            store.change_state(heartbeat)
            with patch.object(control, "service_states", return_value=active_services()):
                snap = control.status()
                assert not snap["scheduler_problem"]
                assert not control._scheduler_problem(active_services(), snap["runtime"], now)
            # Even an unavailable service must not produce a 100-event
            # unavailable/recovered flood from read-only status refreshes.
            inactive = active_services()
            inactive["bridge"]["state"] = "inactive"
            with patch.object(control, "service_states", return_value=inactive):
                for _ in range(5):
                    assert "inactive" in control.status()["scheduler_problem"]
            assert store.read_snapshot()[1]["events"] == []

    # Each mode gets first claim following its explicit Start even though
    # the built-in continuous profile is due earlier.
    for mode in ("manual", "continuous", "interval", "duration", "iterations"):
        with tempfile.TemporaryDirectory() as tmp:
            with patch.dict(os.environ, {"XDG_CONFIG_HOME": tmp + "/config",
                                         "XDG_STATE_HOME": tmp + "/state"}):
                pid = control.create_profile("Custom " + mode)["profile_id"]
                control.set_profile(pid, "enabled", "true")
                if mode == "iterations":
                    control.set_profile(pid, "iteration_limit", "2")
                control.set_profile(pid, "mode", '"' + mode + '"')
                with patch.object(control, "_ensure_runtime_services"), \
                     patch.object(control, "_await_dispatch"):
                    control.profile_action("start", pid)
                before = store.read_snapshot()[1]
                seq = before["command_seq"]
                assert seq > before["command_ack_seq"]
                assert before["requested_profile_id"] == pid
                commands = []
                with patch.object(daemon, "desktop_command",
                                  side_effect=desktop_for_initial(commands)):
                    daemon.tick(int(time.time()))
                after = store.read_snapshot()[1]
                assert after["owner_id"] == pid, mode
                assert after["command_ack_seq"] >= seq
                assert after["requested_profile_id"] is None
                assert after["profiles"][pid]["pending"] is not None
                assert commands == ["new-chat", "managed-baseline", "managed-submit"]
                control._await_dispatch(pid, seq)

    # Reproduce the uploaded field report: live owner, old restart request,
    # pending reply, four polling errors and a misleading Scheduled status.
    with tempfile.TemporaryDirectory() as tmp:
        with patch.dict(os.environ, {"XDG_CONFIG_HOME": tmp + "/config",
                                     "XDG_STATE_HOME": tmp + "/state"}):
            pid = "strict-lossless-research"
            now = int(time.time())
            def stranded(_config, state):
                state["owner_id"] = pid
                item = state["profiles"][pid]
                item.update({
                    "desired": "run", "status": "scheduled", "request": "restart",
                    "loop_state": "connector_blocked", "poll_errors": 4,
                    "failures": 15, "prompts_sent": 3,
                    "chat_started_at_unix": now - 100,
                    "pending": {
                        "response_action_count": 2, "kind": "initial",
                        "prepared_at_unix": now - 300, "poll_after_unix": now + 1000,
                        "counted": True,
                    },
                })
            store.change_state(stranded)

            with patch.object(control, "_ensure_runtime_services"), \
                 patch.object(control, "_await_dispatch"):
                control.profile_action("restart", pid)
            resumed = store.read_snapshot()[1]
            item = resumed["profiles"][pid]
            assert item["poll_errors"] == 0
            assert item["pending"]["response_action_count"] == 2
            assert item["status"] == "restart_queued"
            assert item["request"] == "restart"

            calls = []
            poll_count = 0
            def desktop(command, *args, prompt=None, project_name=None):
                nonlocal poll_count
                calls.append(command)
                if command == "managed-poll":
                    poll_count += 1
                    assert args[0] == "2"
                    if poll_count == 1:
                        return {"completed": False}
                    # This belongs to the OLD prompt, not the requested restart.
                    return {"completed": True, "response": {
                        "text": "HADALIS_LOOP:CONNECTOR_BLOCKED GITHUB"}}
                if command == "new-chat":
                    return {}
                if command == "managed-baseline":
                    return {"responseActionCount": 0}
                if command == "managed-submit":
                    assert prompt is not None
                    return {"submitted": True}
                raise AssertionError(command)
            with patch.object(daemon, "desktop_command", side_effect=desktop):
                daemon.tick(now + 1)
                first = store.read_snapshot()[1]["profiles"][pid]
                assert first["pending"] is not None
                assert first["prompts_sent"] == 3
                assert calls == ["managed-poll"]
                daemon.tick(now + 3)
                second = store.read_snapshot()[1]["profiles"][pid]
                assert second["pending"] is None
                assert second["status"] == "rotating"
                assert second["desired"] == "run"
                assert second["prompts_sent"] == 3
                assert calls == ["managed-poll", "managed-poll"]
                daemon.tick(now + 5)
            third = store.read_snapshot()[1]["profiles"][pid]
            assert calls == ["managed-poll", "managed-poll", "new-chat",
                             "managed-baseline", "managed-submit"]
            assert third["pending"] is not None
            assert third["prompts_sent"] == 4

    # Start (without Restart) also re-observes the existing response when
    # an owner exceeded the polling limit. It must never clear its baseline.
    with tempfile.TemporaryDirectory() as tmp:
        with patch.dict(os.environ, {"XDG_CONFIG_HOME": tmp + "/config",
                                     "XDG_STATE_HOME": tmp + "/state"}):
            pid = "strict-lossless-research"
            def stalled(_config, state):
                state["owner_id"] = pid
                state["profiles"][pid].update({
                    "status": "scheduled", "desired": "run", "poll_errors": 4,
                    "pending": {
                        "response_action_count": 1, "kind": "initial",
                        "poll_after_unix": int(time.time()) + 800,
                        "counted": True,
                    },
                })
            store.change_state(stalled)
            with patch.object(control, "_ensure_runtime_services"), \
                 patch.object(control, "_await_dispatch"):
                control.profile_action("start", pid)
            item = store.read_snapshot()[1]["profiles"][pid]
            assert item["status"] == "recovering_pending"
            assert item["poll_errors"] == 0
            assert item["pending"]["response_action_count"] == 1
            assert any(e["kind"] == "pending_recovery_requested"
                       for e in store.read_snapshot()[1]["events"])

    # A fresh heartbeat from an older daemon is insufficient: each Start
    # needs a command-specific acknowledgement, otherwise emit a clear error.
    with tempfile.TemporaryDirectory() as tmp:
        with patch.dict(os.environ, {"XDG_CONFIG_HOME": tmp + "/config",
                                     "XDG_STATE_HOME": tmp + "/state"}):
            pid = "strict-lossless-research"
            def old_daemon(_config, state):
                state["owner_id"] = pid
                state["manager_heartbeat_at_unix"] = int(time.time())
                state["command_seq"] = 1
                state["command_ack_seq"] = 0
                state["profiles"][pid]["command_seq"] = 1
            store.change_state(old_daemon)
            with patch.object(control, "DISPATCH_ACK_SECONDS", 0):
                try:
                    control._await_dispatch(pid, 1)
                except RuntimeError as exc:
                    assert "not dispatched" in str(exc)
                else:
                    raise AssertionError("an old daemon must not acknowledge Start")
    print("PASS: split-checkout, read-only health, five modes and safe pending recovery")


if __name__ == "__main__":
    main()
