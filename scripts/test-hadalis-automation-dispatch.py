#!/usr/bin/env python3
"""Explicit Start dispatch contract across all five Automation modes."""
from __future__ import annotations

import os
from pathlib import Path
import sys
import tempfile
import time
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from automation.manager import control, daemon, store  # noqa: E402


def main() -> None:
    for mode in ("manual", "continuous", "interval", "duration", "iterations"):
        with tempfile.TemporaryDirectory() as tmp:
            with patch.dict(os.environ, {
                    "XDG_CONFIG_HOME": tmp + "/config",
                    "XDG_STATE_HOME": tmp + "/state"}):
                pid = control.create_profile("Mode " + mode)["profile_id"]
                control.set_profile(pid, "enabled", "true")
                if mode == "iterations":
                    control.set_profile(pid, "iteration_limit", "2")
                control.set_profile(pid, "mode", '"' + mode + '"')

                with patch.object(control, "_ensure_runtime_services"), \
                     patch.object(control, "_await_dispatch"):
                    control.profile_action("start", pid)
                before = store.read_snapshot()[1]
                assert before["requested_profile_id"] == pid
                assert before["profiles"][pid]["status"] == "scheduled"
                # Built-in continuous is also due; explicit Start must win.
                assert before["profiles"]["strict-lossless-research"]["desired"] == "run"

                commands = []
                def desktop(command, *args, prompt=None, project_name=None):
                    commands.append(command)
                    assert project_name == "Hadalis Cloud"
                    if command == "managed-baseline":
                        return {"responseActionCount": 0}
                    if command == "managed-submit":
                        assert prompt and "[@GitHub]" in prompt
                        return {"submitted": True}
                    if command == "new-chat":
                        return {}
                    raise AssertionError(command)

                with patch.object(daemon, "desktop_command", side_effect=desktop):
                    daemon.tick(int(time.time()) + 1)
                after = store.read_snapshot()[1]
                assert after["owner_id"] == pid, (mode, after["owner_id"])
                assert after["requested_profile_id"] is None
                assert after["profiles"][pid]["status"] == "thinking"
                assert after["profiles"][pid]["pending"] is not None
                assert after["profiles"][pid]["prompts_sent"] == 1
                assert commands == ["new-chat", "managed-baseline", "managed-submit"]

    # Receipt is a *real* manager heartbeat and current ownership, not just
    # systemctl ActiveState or a stored request flag.
    with tempfile.TemporaryDirectory() as tmp:
        with patch.dict(os.environ, {
                "XDG_CONFIG_HOME": tmp + "/config",
                "XDG_STATE_HOME": tmp + "/state"}):
            pid = "strict-lossless-research"
            def ready(_config, state):
                state["manager_heartbeat_at_unix"] = int(time.time())
                state["owner_id"] = pid
                state["profiles"][pid]["status"] = "thinking"
            store.change_state(ready)
            control._await_dispatch(pid)

            # A genuinely occupied composer is reported as queued rather than
            # falsely claiming the target is running.
            second = control.create_profile("Queued")["profile_id"]
            store.change_state(lambda _config, state: state["profiles"][second].update({
                "status": "waiting_owner",
                "status_detail": "Waiting for active owner"}))
            control._await_dispatch(second)

            def unresponsive(_config, state):
                state["owner_id"] = None
                state["manager_heartbeat_at_unix"] = None
            store.change_state(unresponsive)
            with patch.object(control, "DISPATCH_ACK_SECONDS", 0):
                try:
                    control._await_dispatch(second)
                except RuntimeError as exc:
                    assert "was not dispatched" in str(exc)
                else:
                    raise AssertionError("expected error on missing scheduler receipt")

            control.set_profile(second, "enabled", "true")
            with patch.object(control, "_ensure_runtime_services"), \
                 patch.object(control, "DISPATCH_ACK_SECONDS", 0):
                try:
                    control.profile_action("start", second)
                except RuntimeError as exc:
                    assert "was not dispatched" in str(exc)
                else:
                    raise AssertionError("Start must reject missing scheduler receipt")
            failure = store.read_snapshot()[1]["profiles"][second]
            assert failure["status"] == "scheduler_unavailable"
            assert any(event["kind"] == "start_failed" and event["profile_id"] == second
                       for event in store.read_snapshot()[1]["events"])

    print("PASS: explicit Start dispatch for all modes, priority, and scheduler receipt")


if __name__ == "__main__":
    main()
