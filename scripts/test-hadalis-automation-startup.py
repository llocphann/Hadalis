#!/usr/bin/env python3
"""Regression: profile controls activate the scheduler and expose failures."""
from __future__ import annotations

import os
from pathlib import Path
import sys
import tempfile
import time
from types import SimpleNamespace
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from automation.manager import control, daemon, store  # noqa: E402


def services(**overrides):
    return {key: {"state": overrides.get(key, "active"),
                  "detail": "running", "result": ""}
            for key in control.UNITS}


def main() -> None:
    initial = services(chatgpt="inactive", worker="inactive", bridge="inactive")
    with patch.object(control, "service_states", side_effect=[initial, services()]):
        with patch.object(control.subprocess, "run",
                          return_value=SimpleNamespace(returncode=0, stdout="", stderr="")) as run:
            control._ensure_runtime_services()
            assert [call.args[0][-1] for call in run.call_args_list] == [
                control.UNITS["chatgpt"], control.UNITS["worker"], control.UNITS["bridge"]]

    mismatched = services()
    mismatched["bridge"]["working_directory"] = "/tmp/old-hadalis-checkout"
    assert "old checkout" in control._runtime_unit_problem(mismatched)
    mismatched["bridge"]["working_directory"] = str(control.ROOT)
    mismatched["bridge"]["exec_start"] = "python3 -m automation.chat_bridge.controller"
    assert "does not run" in control._runtime_unit_problem(mismatched)

    with patch.object(control, "service_states",
                      return_value=services(bridge="unavailable")):
        try:
            control._ensure_runtime_services()
        except RuntimeError as exc:
            assert "install-hadalis-automation.py" in str(exc)
        else:
            raise AssertionError("uninstalled scheduler must not report ready")

    with tempfile.TemporaryDirectory() as tmp:
        with patch.dict(os.environ, {
                "XDG_CONFIG_HOME": tmp + "/config",
                "XDG_STATE_HOME": tmp + "/state"}):
            pid = "strict-lossless-research"

            def stale(_config, runtime):
                runtime["owner_id"] = pid
                runtime["manager_heartbeat_at_unix"] = int(time.time()) - 200
                runtime["profiles"][pid]["status"] = "continuing"

            store.change_state(stale)

            with patch.object(control, "service_states",
                              return_value=services(bridge="inactive")):
                snapshot = control.status()
                repeated = control.status()
            item = repeated["runtime"]["profiles"][pid]
            assert item["status"] == "scheduler_unavailable"
            assert "Chat bridge is inactive" in item["last_error"]
            assert len([entry for entry in repeated["runtime"]["events"]
                        if entry["kind"] == "scheduler_unavailable"]) == 1
            assert snapshot["services"]["bridge"]["state"] == "inactive"

            with patch.object(control, "service_states", return_value=services()):
                stale_heartbeat = control.status()
            assert "heartbeat is older" in stale_heartbeat["runtime"]["profiles"][pid]["last_error"]

            store.change_state(lambda _config, runtime: daemon._heartbeat(runtime, int(time.time())))
            assert store.read_snapshot()[1]["profiles"][pid]["status"] == "scheduled"

            with patch.object(control, "_ensure_runtime_services",
                              side_effect=RuntimeError("ChatGPT CDP endpoint unavailable")):
                try:
                    control.profile_action("start", pid)
                except RuntimeError as exc:
                    assert "CDP endpoint" in str(exc)
                else:
                    raise AssertionError("failed runtime start must fail the action")
            item = store.read_snapshot()[1]["profiles"][pid]
            assert item["status"] == "scheduler_unavailable"
            assert "CDP endpoint" in item["last_error"]
            assert any(entry["kind"] == "start_failed"
                       for entry in store.read_snapshot()[1]["events"])

            def waiting_job(_config, runtime):
                runtime["profiles"][pid].update({
                    "job_id": "JOB-STUCK", "status": "waiting_result",
                    "pending": None, "next_job_poll_at_unix": int(time.time()) + 10})

            store.change_state(waiting_job)
            with patch.object(control, "_ensure_runtime_services"), patch.object(control, "_await_dispatch"):
                control.profile_action("restart", pid)
            item = store.read_snapshot()[1]["profiles"][pid]
            assert item["job_id"] is None and item["request"] == "restart"
            assert item["status"] == "scheduled"
            assert any(entry["kind"] == "job_wait_abandoned"
                       for entry in store.read_snapshot()[1]["events"])

            store.change_state(lambda _config, runtime: daemon._configuration_problem(
                runtime, ["malformed profile"]))
            item = store.read_snapshot()[1]["profiles"][pid]
            assert item["status"] == "invalid_configuration"
            assert any(entry["kind"] == "invalid_configuration"
                       for entry in store.read_snapshot()[1]["events"])
    with tempfile.TemporaryDirectory() as tmp:
        with patch.dict(os.environ, {
                "XDG_CONFIG_HOME": tmp + "/config",
                "XDG_STATE_HOME": tmp + "/state"}):
            pid = "strict-lossless-research"
            def owned(_config, runtime):
                runtime["owner_id"] = pid
                runtime["profiles"][pid]["status"] = "thinking"
                runtime["manager_heartbeat_at_unix"] = int(time.time())
            store.change_state(owned)
            control._await_dispatch(pid)  # A live scheduler can acknowledge an owned run.
            store.change_state(lambda _config, runtime: runtime.update({
                "owner_id": None, "manager_heartbeat_at_unix": None}))
            with patch.object(control, "DISPATCH_ACK_SECONDS", 0):
                try:
                    control._await_dispatch(pid)
                except RuntimeError as exc:
                    assert "was not dispatched" in str(exc)
                else:
                    raise AssertionError("a unit's ActiveState is not proof of dispatch")
    print("PASS: Automation runtime startup, heartbeat, errors and restart")


if __name__ == "__main__":
    main()
