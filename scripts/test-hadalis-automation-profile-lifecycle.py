#!/usr/bin/env python3
"""Regression for editable/removable original Automation profiles."""
from __future__ import annotations

import json
import os
from pathlib import Path
import sys
import tempfile
import time
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from automation.manager import control, daemon, model, store  # noqa: E402


def main() -> None:
    # Project edits are configuration for the next new chat. A live/pending
    # chat keeps the project it was opened in so polling cannot jump projects.
    with tempfile.TemporaryDirectory() as tmp:
        with patch.dict(os.environ, {
                "XDG_CONFIG_HOME": tmp + "/config",
                "XDG_STATE_HOME": tmp + "/state"}):
            pid = model.DEFAULT_ID
            base = int(time.time())
            commands: list[tuple[str, str | None]] = []
            polls = 0

            def desktop(command, *args, prompt=None, project_name=None):
                nonlocal polls
                commands.append((command, project_name))
                if command == "new-chat":
                    return {}
                if command == "managed-baseline":
                    return {"responseActionCount": 0}
                if command == "managed-submit":
                    return {"submitted": True}
                if command == "managed-poll":
                    polls += 1
                    if polls == 1:
                        return {"completed": False}
                    return {"completed": True, "response": {
                        "text": "HADALIS_LOOP:CONTINUE"}}
                raise AssertionError(command)

            with patch.object(daemon, "desktop_command", side_effect=desktop):
                daemon.tick(base)
                runtime = store.read_snapshot()[1]
                assert runtime["owner_id"] == pid
                assert runtime["profiles"][pid]["pending"] is not None
                assert runtime["profiles"][pid]["active_project_name"] == "Hadalis Cloud"

                # Simulate an in-flight state created before active_project_name
                # existed; the edit must snapshot the old project before changing config.
                store.change_state(lambda _config, state: state["profiles"][pid].update(
                    {"active_project_name": ""}))
                control.set_profile(pid, "project_name", json.dumps("Renamed Project"))
                config, runtime, _ = store.read_snapshot()
                assert config["profiles"][0]["project_name"] == "Renamed Project"
                assert runtime["profiles"][pid]["active_project_name"] == "Hadalis Cloud"

                daemon.tick(base + 2)
                assert commands[-1] == ("managed-poll", "Hadalis Cloud")

                control.profile_action("stop", pid)
                daemon.tick(base + 4)
                runtime = store.read_snapshot()[1]
                assert runtime["owner_id"] is None
                assert runtime["profiles"][pid]["active_project_name"] == ""

                with patch.object(control, "_ensure_runtime_services"), \
                     patch.object(control, "_await_dispatch"):
                    control.profile_action("start", pid)
                daemon.tick(base + 6)

            assert ("new-chat", "Renamed Project") in commands
            renamed_new_chat = commands.index(("new-chat", "Renamed Project"))
            assert commands[renamed_new_chat + 1] == ("managed-baseline", "Renamed Project")
            assert commands[renamed_new_chat + 2] == ("managed-submit", "Renamed Project")

    # The original seeded profile is not structurally special after creation:
    # it can be removed, and an explicit empty profile list remains empty.
    with tempfile.TemporaryDirectory() as tmp:
        with patch.dict(os.environ, {
                "XDG_CONFIG_HOME": tmp + "/config",
                "XDG_STATE_HOME": tmp + "/state"}):
            pid = model.DEFAULT_ID
            control.set_profile(pid, "enabled", "false")
            control.remove_profile(pid)
            config, runtime, issues = store.read_snapshot()
            assert not issues
            assert config["profiles"] == []
            assert runtime["profiles"] == {}
            assert runtime["owner_id"] is None

            created = control.create_profile("Replacement")
            assert store.read_snapshot()[0]["profiles"][0]["id"] == created["profile_id"]

    # A previously parked unresolved turn was already explicitly abandoned
    # from automatic recovery. Removing that profile may discard only its
    # local recovery metadata while retaining ChatGPT history.
    with tempfile.TemporaryDirectory() as tmp:
        with patch.dict(os.environ, {
                "XDG_CONFIG_HOME": tmp + "/config",
                "XDG_STATE_HOME": tmp + "/state"}):
            old = model.DEFAULT_ID
            replacement = control.create_profile("Replacement")["profile_id"]
            control.set_profile(old, "enabled", "false")

            def parked(_config, state):
                item = state["profiles"][old]
                item.update({
                    "desired": "stopped",
                    "status": "parked_unresolved",
                    "parked_pending": True,
                    "active_project_name": "Hadalis Cloud",
                    "pending": {
                        "response_action_count": 3,
                        "kind": "initial",
                        "prepared_at_unix": int(time.time()) - 30,
                        "poll_after_unix": int(time.time()) + 30,
                        "counted": True,
                    },
                })
            store.change_state(parked)
            control.remove_profile(old)
            config, runtime, _ = store.read_snapshot()
            assert old not in runtime["profiles"]
            assert [p["id"] for p in config["profiles"]] == [replacement]
            assert any(e["kind"] == "removed" and
                       "parked recovery metadata discarded" in e["detail"]
                       for e in runtime["events"])

    print("PASS: original profile project staging, deletion, and parked cleanup")


if __name__ == "__main__":
    main()
