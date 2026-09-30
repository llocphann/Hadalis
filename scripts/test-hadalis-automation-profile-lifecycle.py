#!/usr/bin/env python3
"""Regression for editable/removable original Automation profiles."""
from __future__ import annotations

import json
import fcntl
import os
from pathlib import Path
import sys
import stat
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

    # Explicit removal also works with a lost Desktop endpoint. The running
    # scheduler finishes its current command before releasing the old owner.
    # A private copy preserves the unresolved baseline; no Desktop operation
    # is used to remove the local profile.
    for scheduler_running in (True, False):
        with tempfile.TemporaryDirectory() as tmp:
            with patch.dict(os.environ, {"XDG_CONFIG_HOME": tmp + "/config",
                                         "XDG_STATE_HOME": tmp + "/state"}):
                old = model.DEFAULT_ID
                new = control.create_profile("Replacement")["profile_id"]
                control.set_profile(new, "enabled", "true")
                now = int(time.time())
                baseline = {"response_action_count": 3, "kind": "continuation",
                            "prepared_at_unix": now - 30, "counted": True}
                def stranded(_config, state):
                    state["owner_id"] = old
                    state["requested_profile_id"] = new
                    state["profiles"][old].update({"desired": "stopped",
                        "status": "transport_unavailable", "pending": baseline,
                        "active_project_name": "Original Project"})
                    state["profiles"][new].update({"desired": "run",
                        "status": "waiting_owner", "next_run_at_unix": now})
                store.change_state(stranded)
                # Ordinary removal still protects a potentially submitted turn.
                try:
                    control.remove_profile(old)
                except ValueError:
                    pass
                else:
                    raise AssertionError("unresolved removal needs explicit confirmation")

                with (store.state_dir() / "chat-bridge.lock").open("a+") as lock:
                    if scheduler_running:
                        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                    with patch.object(daemon, "desktop_command") as desktop:
                        control.remove_profile(old, confirmed_unresolved=True)
                        if scheduler_running:
                            config, runtime, _ = store.read_snapshot()
                            assert runtime["owner_id"] == old
                            assert runtime["profiles"][old]["remove_requested"]
                            try:
                                control.profile_action("start", old)
                            except ValueError as exc:
                                assert "being removed" in str(exc)
                            else:
                                raise AssertionError("removed run must not resume")

                            # Archive failures cannot lose the old pending turn.
                            with patch.object(daemon, "archive_removed_profile",
                                              side_effect=OSError("disk full")):
                                try:
                                    daemon.tick(now)
                                except OSError:
                                    pass
                                else:
                                    raise AssertionError("archive failure must be visible")
                            assert store.read_snapshot()[1]["owner_id"] == old
                            daemon.tick(now + 1)
                        desktop.assert_not_called()

                config, runtime, _ = store.read_snapshot()
                assert runtime["owner_id"] is None
                assert old not in runtime["profiles"]
                assert runtime["requested_profile_id"] == new
                assert runtime["profiles"][new]["desired"] == "run"
                copies = list((store.state_dir() / "removed-profiles").glob("*.json"))
                assert len(copies) == 1
                assert stat.S_IMODE(copies[0].stat().st_mode) == 0o600
                saved = json.loads(copies[0].read_text())
                assert saved["profile"]["id"] == old
                assert saved["runtime"]["pending"] == baseline
                assert saved["runtime"]["active_project_name"] == "Original Project"
                commands = []
                def desktop(command, *args, **kwargs):
                    commands.append(command)
                    return {"responseActionCount": 0} if command == "managed-baseline" else {}
                with patch.object(daemon, "desktop_command", side_effect=desktop):
                    daemon.tick(now + 2)
                assert store.read_snapshot()[1]["owner_id"] == new
                assert commands == ["new-chat", "managed-baseline", "managed-submit"]

    # Polling errors must not undo an explicit Stop (which blocked parking).
    with tempfile.TemporaryDirectory() as tmp:
        with patch.dict(os.environ, {"XDG_CONFIG_HOME": tmp + "/config",
                                     "XDG_STATE_HOME": tmp + "/state"}):
            old = model.DEFAULT_ID
            def stopped(config, state):
                state["owner_id"] = old
                state["profiles"][old].update({"desired": "stopped",
                    "pending": {"response_action_count": 1},
                    "poll_errors": config["profiles"][0]["max_poll_errors"]})
            store.change_state(stopped)
            config, runtime, _ = store.read_snapshot()
            with patch.object(daemon, "desktop_command", side_effect=RuntimeError("CDP unavailable")):
                daemon._poll(config, runtime, old, int(time.time()))
            assert store.read_snapshot()[1]["profiles"][old]["desired"] == "stopped"
            assert store.read_snapshot()[1]["profiles"][old]["poll_errors"] > config["profiles"][0]["max_poll_errors"]

    print("PASS: original profile lifecycle, confirmed unresolved removal, private recovery and safe handover")


if __name__ == "__main__":
    main()
