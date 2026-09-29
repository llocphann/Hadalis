#!/usr/bin/env python3
"""Exercise transport ownership and safe boundary transitions without Desktop."""
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
    with tempfile.TemporaryDirectory() as tmp:
        with patch.dict(os.environ, {"XDG_CONFIG_HOME": tmp + "/config", "XDG_STATE_HOME": tmp + "/state"}):
            calls = []
            replies = ["HADALIS_LOOP:CONTINUE", "HADALIS_LOOP:CONTINUE",
                       "HADALIS_LOOP:CONTINUE"]

            def desktop(command, *args, prompt=None):
                calls.append((command, args, prompt))
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

                second = control.create_profile("Second profile")["profile_id"]
                control.set_profile(second, "enabled", "true")
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
    print("PASS: one ChatGPT transport owner, safe pause/stop, queued profile")


if __name__ == "__main__":
    main()
