#!/usr/bin/env python3
"""Regression for explicitly parking an unreachable pending Automation turn."""
from __future__ import annotations

import os
from pathlib import Path
import sys
import tempfile
import time
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from automation.manager import control, daemon, store  # noqa: E402


def seed_blocked_handover():
    old = "strict-lossless-research"
    control.set_profile(old, "enabled", "false")
    new = control.create_profile("Replacement")["profile_id"]
    control.set_profile(new, "enabled", "true")
    control.set_profile(new, "project_name", '"Replacement Project"')
    now = int(time.time())

    def blocked(_config, state):
        state["owner_id"] = old
        state["requested_profile_id"] = new
        old_item = state["profiles"][old]
        old_item.update({
            "desired": "stopped",
            "status": "waiting_desktop",
            "last_error": "Hadalis Cloud project guard is not visible; waiting for target chat",
            "status_detail": "Yielding transport after the existing response is resolved",
            "pending": {
                "response_action_count": 4,
                "kind": "initial",
                "prepared_at_unix": now - 100,
                "poll_after_unix": now + 30,
                "counted": True,
            },
        })
        state["profiles"][new].update({
            "desired": "run",
            "status": "waiting_owner",
            "next_run_at_unix": now,
        })
    store.change_state(blocked)
    return old, new, now


def main() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        with patch.dict(os.environ, {
                "XDG_CONFIG_HOME": tmp + "/config",
                "XDG_STATE_HOME": tmp + "/state"}):
            old, new, now = seed_blocked_handover()
            control.request_park_unresolved(old)
            requested = store.read_snapshot()[1]
            assert requested["profiles"][old]["park_requested"] is True

            config, state, _ = store.read_snapshot()
            with patch.object(daemon, "desktop_command", return_value={
                    "projectGuardVisible": 0,
                    "generationActive": False,
                    "composerReady": True,
                    "draftPresent": False}):
                assert daemon._handle_park_request(config, state, old, now + 1)
            parked = store.read_snapshot()[1]
            old_item = parked["profiles"][old]
            target = parked["profiles"][new]
            assert parked["owner_id"] is None
            assert parked["requested_profile_id"] == new
            assert old_item["parked_pending"] is True
            assert old_item["park_requested"] is False
            assert old_item["pending"]["response_action_count"] == 4
            assert old_item["status"] == "parked_unresolved"
            assert target["status"] == "scheduled"
            assert any(e["kind"] == "pending_parked" for e in parked["events"])

            # Parked unresolved runs are never silently started again.
            control.set_profile(old, "enabled", "true")
            with patch.object(control, "_ensure_runtime_services"):
                try:
                    control.profile_action("start", old)
                except ValueError as exc:
                    assert "parked unresolved response" in str(exc)
                else:
                    raise AssertionError("parked unresolved profile must require reconciliation")

            # The queued replacement owns the next turn and submits only its own prompt.
            commands = []
            def desktop(command, *args, prompt=None, project_name=None):
                commands.append((command, project_name))
                if command == "new-chat":
                    return {}
                if command == "managed-baseline":
                    return {"responseActionCount": 0}
                if command == "managed-submit":
                    assert prompt and "[@GitHub]" in prompt
                    return {"submitted": True}
                raise AssertionError(command)
            control.set_profile(old, "enabled", "false")
            with patch.object(daemon, "desktop_command", side_effect=desktop):
                daemon.tick(now + 3)
            after = store.read_snapshot()[1]
            assert after["owner_id"] == new
            assert after["profiles"][new]["pending"] is not None
            assert after["profiles"][old]["pending"]["response_action_count"] == 4
            assert [name for name, _project in commands] == [
                "new-chat", "managed-baseline", "managed-submit"]
            assert all(project == "Replacement Project" for _name, project in commands)

    # Never park while the original project is visible again.
    with tempfile.TemporaryDirectory() as tmp:
        with patch.dict(os.environ, {
                "XDG_CONFIG_HOME": tmp + "/config",
                "XDG_STATE_HOME": tmp + "/state"}):
            old, new, now = seed_blocked_handover()
            control.request_park_unresolved(old)
            config, state, _ = store.read_snapshot()
            with patch.object(daemon, "desktop_command", return_value={
                    "projectGuardVisible": 1,
                    "generationActive": False,
                    "composerReady": True,
                    "draftPresent": False}):
                daemon._handle_park_request(config, state, old, now + 1)
            current = store.read_snapshot()[1]
            assert current["owner_id"] == old
            assert current["profiles"][old]["parked_pending"] is False
            assert current["profiles"][old]["pending"] is not None
            assert current["profiles"][old]["status"] == "recovering_pending"
            assert current["profiles"][old]["pending"]["poll_after_unix"] == now + 1
            assert current["requested_profile_id"] == new

    # Also fail closed when the currently visible Desktop chat is busy or has a draft.
    for check in (
        {"projectGuardVisible": 0, "generationActive": True,
         "composerReady": True, "draftPresent": False},
        {"projectGuardVisible": 0, "generationActive": False,
         "composerReady": True, "draftPresent": True},
        {"projectGuardVisible": 0, "generationActive": False,
         "composerReady": False, "draftPresent": False},
    ):
        with tempfile.TemporaryDirectory() as tmp:
            with patch.dict(os.environ, {
                    "XDG_CONFIG_HOME": tmp + "/config",
                    "XDG_STATE_HOME": tmp + "/state"}):
                old, _new, now = seed_blocked_handover()
                control.request_park_unresolved(old)
                config, state, _ = store.read_snapshot()
                with patch.object(daemon, "desktop_command", return_value=check):
                    daemon._handle_park_request(config, state, old, now + 1)
                current = store.read_snapshot()[1]
                assert current["owner_id"] == old
                assert current["profiles"][old]["pending"] is not None
                assert current["profiles"][old]["parked_pending"] is False
                assert current["profiles"][old]["park_requested"] is False
                assert any(e["kind"] == "park_rejected" for e in current["events"])

    print("PASS: explicit parked-response handover preserves pending state and unblocks replacement")


if __name__ == "__main__":
    main()
