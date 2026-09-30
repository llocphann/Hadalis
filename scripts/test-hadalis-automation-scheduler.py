#!/usr/bin/env python3
"""Exercise transport ownership and safe boundary transitions without Desktop."""
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


def main() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        with patch.dict(os.environ, {"XDG_CONFIG_HOME": tmp + "/config", "XDG_STATE_HOME": tmp + "/state"}):
            calls = []
            replies = ["HADALIS_LOOP:CONTINUE", "HADALIS_LOOP:CONTINUE",
                       "HADALIS_LOOP:CONTINUE"]

            def desktop(command, *args, prompt=None, project_name=None):
                calls.append((command, args, prompt))
                assert project_name == "Hadalis Cloud"
                if command == "new-chat":
                    return {"composerVisible": 1}
                if command == "managed-baseline":
                    return {"responseActionCount": 0}
                if command == "managed-submit":
                    assert prompt and "[@GitHub]" in prompt
                    return {"submitted": True}
                if command == "managed-poll":
                    return {"completed": True, "response": {"text": replies.pop(0)}}
                raise AssertionError(command)

            default = "strict-lossless-research"
            base = int(time.time())
            with patch.object(daemon, "desktop_command", side_effect=desktop):
                daemon.tick(base)
                config, state, _ = store.read_snapshot()
                assert state["owner_id"] == default
                assert state["profiles"][default]["pending"] is not None
                assert state["profiles"][default]["prompts_sent"] == 1
                assert calls[0][:2] == ("new-chat", ("--unowned-previous-chat",))

                second = control.create_profile("Second profile")["profile_id"]
                control.set_profile(second, "enabled", "true")
                with patch.object(control, "_ensure_runtime_services"):
                    control.profile_action("start", second)
                daemon.tick(base + 2)
                assert store.read_snapshot()[1]["owner_id"] == default
                assert store.read_snapshot()[1]["profiles"][default]["iterations"] == 1
                daemon.tick(base + 4)  # continuation; never opens a second chat
                assert [item[0] for item in calls].count("new-chat") == 1
                control.profile_action("pause", default)
                daemon.tick(base + 6)  # finish in-flight response first
                assert store.read_snapshot()[1]["owner_id"] == default
                assert store.read_snapshot()[1]["profiles"][default]["status"] == "paused"
                assert len(replies) == 1
                daemon.tick(base + 8)  # queued profile cannot steal paused chat
                assert store.read_snapshot()[1]["owner_id"] == default
                control.profile_action("stop", default)
                daemon.tick(base + 10)  # releases after known terminal state
                assert store.read_snapshot()[1]["owner_id"] is None
                daemon.tick(base + 12)
                assert store.read_snapshot()[1]["owner_id"] == second
                assert [item[0] for item in calls].count("new-chat") == 2

            # Unknown submission outcome must retain a pending baseline and
            # never inject the same prompt again.
            config, state, _ = store.read_snapshot()
            assert state["profiles"][second]["pending"] is not None
            control.profile_action("stop", second)
            assert store.read_snapshot()[1]["owner_id"] == second

    with tempfile.TemporaryDirectory() as tmp:
        with patch.dict(os.environ, {"XDG_CONFIG_HOME": tmp + "/config", "XDG_STATE_HOME": tmp + "/state"}):
            commands = []
            def uncertain(command, *args, prompt=None, project_name=None):
                commands.append(command)
                assert project_name == "Hadalis Cloud"
                if command == "new-chat": return {}
                if command == "managed-baseline": return {"responseActionCount": 0}
                if command == "managed-submit": raise RuntimeError("connection lost after send")
                if command == "managed-poll": return {"completed": False}
                raise AssertionError(command)
            base = int(time.time())
            with patch.object(daemon, "desktop_command", side_effect=uncertain):
                daemon.tick(base)
                daemon.tick(base + 2)
                daemon.tick(base + 4)
            state = store.read_snapshot()[1]
            assert state["owner_id"] == "strict-lossless-research"
            assert state["profiles"]["strict-lossless-research"]["pending"] is not None
            assert commands.count("managed-submit") == 1
            assert commands.count("managed-poll") == 2

    for retry_succeeds in (True, False):
        with tempfile.TemporaryDirectory() as tmp:
            with patch.dict(os.environ, {"XDG_CONFIG_HOME": tmp + "/config", "XDG_STATE_HOME": tmp + "/state"}):
                commands = []

                def failed_stream(command, *args, prompt=None, project_name=None):
                    commands.append(command)
                    assert project_name == "Hadalis Cloud"
                    if command == "new-chat": return {}
                    if command == "managed-baseline": return {"responseActionCount": 0}
                    if command == "managed-submit": return {"submitted": True}
                    if command == "managed-retry": return {"retryTriggered": True}
                    if command == "managed-poll" and commands.count("managed-poll") == 1:
                        return {"completed": False, "streamError": True}
                    if command == "managed-poll" and retry_succeeds:
                        return {"completed": True, "response": {"text": "HADALIS_LOOP:CONTINUE"}}
                    if command == "managed-poll":
                        return {"completed": False, "streamError": True}
                    raise AssertionError(command)

                base = int(time.time())
                with patch.object(daemon, "desktop_command", side_effect=failed_stream):
                    daemon.tick(base)
                    daemon.tick(base + 2)
                    item = store.read_snapshot()[1]["profiles"]["strict-lossless-research"]
                    assert item["pending"]["stream_retry_attempts"] == 1
                    assert item["prompts_sent"] == 1
                    assert commands.count("managed-retry") == 1
                    daemon.tick(base + 4)
                    assert commands.count("managed-poll") == 1
                    daemon.tick(base + 32)
                    state = store.read_snapshot()[1]
                    item = state["profiles"]["strict-lossless-research"]
                    if retry_succeeds:
                        assert item["iterations"] == 1 and item["pending"] is None
                        assert item["desired"] == "run"
                    else:
                        assert item["iterations"] == 0 and item["pending"] is not None
                        assert item["desired"] == "paused" and item["status"] == "stream_failed"
                        daemon.tick(base + 33)
                        assert commands.count("managed-poll") == 2
                        with patch.object(control.time, "time", return_value=base + 34):
                            with patch.object(control, "_ensure_runtime_services"):
                                control.profile_action("resume", "strict-lossless-research")
                        resumed = store.read_snapshot()[1]["profiles"]["strict-lossless-research"]
                        assert resumed["pending"]["stream_retry_attempts"] == 0
                    assert commands.count("managed-submit") == 1
                    assert commands.count("managed-retry") == 1

    with patch.object(daemon.subprocess, "run", return_value=SimpleNamespace(
            returncode=1, stderr="HADALIS_DESKTOP_BUSY: generation active\n", stdout="")):
        try:
            daemon.desktop_command("new-chat")
        except daemon.DesktopBusy as exc:
            assert str(exc) == "generation active"
        else:
            raise AssertionError("expected a typed busy condition")

    with patch.object(daemon.subprocess, "run", return_value=SimpleNamespace(
            returncode=1, stderr="HADALIS_DESKTOP_VIEW_CHANGED: another chat selected\n", stdout="")):
        try:
            daemon.desktop_command("managed-poll", "0")
        except daemon.DesktopViewChanged as exc:
            assert str(exc) == "another chat selected"
        else:
            raise AssertionError("expected a typed view-change condition")

    with tempfile.TemporaryDirectory() as tmp:
        with patch.dict(os.environ, {"XDG_CONFIG_HOME": tmp + "/config", "XDG_STATE_HOME": tmp + "/state"}):
            commands = []
            busy_attempts = 0

            def busy_then_ready(command, *args, prompt=None, project_name=None):
                nonlocal busy_attempts
                commands.append((command, args))
                assert project_name == "Hadalis Cloud"
                if command == "new-chat":
                    busy_attempts += 1
                    if busy_attempts <= 2:
                        raise daemon.DesktopBusy("ChatGPT generation is active")
                    return {}
                if command == "managed-baseline":
                    return {"responseActionCount": 0}
                if command == "managed-submit":
                    return {"submitted": True}
                raise AssertionError(command)

            base = int(time.time())
            with patch.object(daemon, "desktop_command", side_effect=busy_then_ready):
                daemon.tick(base)
                state = store.read_snapshot()[1]
                item = state["profiles"]["strict-lossless-research"]
                assert state["owner_id"] == "strict-lossless-research"
                assert item["desired"] == "run" and item["status"] == "waiting_desktop"
                assert item["failures"] == 0 and item["prompts_sent"] == 0
                assert item["next_run_at_unix"] == base + 30
                daemon.tick(base + 2)
                assert busy_attempts == 1
                daemon.tick(base + 30)
                assert busy_attempts == 2
                assert sum(event["kind"] == "desktop_busy" for event in store.read_snapshot()[1]["events"]) == 1
                daemon.tick(base + 60)
                item = store.read_snapshot()[1]["profiles"]["strict-lossless-research"]
                assert item["status"] == "thinking" and item["prompts_sent"] == 1
                assert item["next_run_at_unix"] is None and item["last_error"] == ""
                assert commands.count(("new-chat", ("--unowned-previous-chat",))) == 3

    with tempfile.TemporaryDirectory() as tmp:
        with patch.dict(os.environ, {"XDG_CONFIG_HOME": tmp + "/config", "XDG_STATE_HOME": tmp + "/state"}):
            commands = []

            def pre_send_busy(command, *args, prompt=None, project_name=None):
                commands.append(command)
                assert project_name == "Hadalis Cloud"
                if command == "new-chat":
                    return {}
                if command == "managed-baseline":
                    return {"responseActionCount": 0}
                if command == "managed-submit" and commands.count("managed-submit") == 1:
                    raise daemon.DesktopBusy("generation began before send")
                if command == "managed-submit":
                    return {"submitted": True}
                raise AssertionError(command)

            base = int(time.time())
            with patch.object(daemon, "desktop_command", side_effect=pre_send_busy):
                daemon.tick(base)
                item = store.read_snapshot()[1]["profiles"]["strict-lossless-research"]
                assert item["pending"] is None and item["prompts_sent"] == 0
                assert item["status"] == "waiting_desktop" and item["failures"] == 0
                daemon.tick(base + 30)
                item = store.read_snapshot()[1]["profiles"]["strict-lossless-research"]
                assert item["pending"] is not None and item["prompts_sent"] == 1
                assert commands.count("managed-submit") == 2

    with tempfile.TemporaryDirectory() as tmp:
        with patch.dict(os.environ, {"XDG_CONFIG_HOME": tmp + "/config", "XDG_STATE_HOME": tmp + "/state"}):
            commands = []

            def moved_view(command, *args, prompt=None, project_name=None):
                commands.append(command)
                assert project_name == "Hadalis Cloud"
                if command == "new-chat":
                    return {}
                if command == "managed-baseline":
                    return {"responseActionCount": 0}
                if command == "managed-submit":
                    return {"submitted": True}
                if command == "managed-poll" and commands.count("managed-poll") == 1:
                    raise daemon.DesktopViewChanged("target project is not selected")
                if command == "managed-poll":
                    return {"completed": False}
                raise AssertionError(command)

            base = int(time.time())
            with patch.object(daemon, "desktop_command", side_effect=moved_view):
                daemon.tick(base)
                daemon.tick(base + 2)
                state = store.read_snapshot()[1]
                item = state["profiles"]["strict-lossless-research"]
                assert item["desired"] == "run" and item["status"] == "waiting_desktop"
                assert item["pending"] is not None and item["pending"]["counted"]
                assert item["pending"]["poll_after_unix"] == base + 32
                assert item["failures"] == 0 and item["poll_errors"] == 0
                assert sum(event["kind"] == "desktop_view_changed" for event in state["events"]) == 1
                daemon.tick(base + 4)
                assert commands.count("managed-poll") == 1
                store.change_state(lambda _config, current: current["profiles"]["strict-lossless-research"].update(
                    {"poll_errors": 1, "last_error": "earlier transient error"}))
                daemon.tick(base + 32)
                item = store.read_snapshot()[1]["profiles"]["strict-lossless-research"]
                assert item["status"] == "thinking" and item["pending"] is not None
                assert item["poll_errors"] == 0 and item["last_error"] == ""
                assert item["prompts_sent"] == 1 and commands.count("managed-submit") == 1
    print("PASS: one ChatGPT owner, busy wait, safe pause/stop, queued profile")


if __name__ == "__main__":
    main()
