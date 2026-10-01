#!/usr/bin/env python3
"""Thinking preferences isolate profiles and cannot replay a pending turn."""
import copy
import json
from pathlib import Path
import subprocess
from unittest.mock import patch

from automation_test_helpers import environment, profile, Transport, daemon, control, model, store


def main():
    legacy = {"id":"old-profile", "name":"Older profile", "prompt":"Keep the objective"}
    config, issues = model.normalize_config({"version":1, "profiles":[legacy]})
    assert not issues and config["profiles"][0]["thinking_effort"] == "auto"
    assert config["profiles"][0]["prompt"] == legacy["prompt"]
    source = model.update_profile(model.new_profile("Source"), {"thinking_effort":"extended"})
    assert model.new_profile("Duplicate", copy=source)["thinking_effort"] == "extended"
    for invalid in (None, [], {}, 1, True, "high", "ultra", "private-canary"):
        try: model.update_profile(source, {"thinking_effort":invalid})
        except ValueError as exc: assert str(exc) == "invalid thinking_effort"
        else: raise AssertionError("unsupported profile effort was accepted")

    with environment():
        a, b = profile("Light chat"), profile("Deep chat")
        control.set_profile(a, "thinking_effort", '"min"')
        control.set_profile(b, "thinking_effort", '"extended"')
        t = Transport()
        def native(op, **data):
            if op == "preflight":
                assert data["requires_github"] is False
                effort = data["thinking_effort"]
                return {"ready":True, "model":"chat-thinking", "thinking_effort":effort}
            if op == "cursor": return {**t(op, **data), "model":"chat-thinking"}
            if op == "submit":
                durable = [i["pending"] for i in store.read_snapshot()[1]["profiles"].values()
                           if (i.get("pending") or {}).get("user_message_id") == data["user_message_id"]]
                assert len(durable) == 1 and durable[0]["model"] == "chat-thinking"
                assert durable[0]["thinking_effort"] == data["thinking_effort"]
            return t(op, **data)
        t.uncertain = True
        with patch.object(daemon, "native_command", side_effect=native): daemon.tick(100)
        originals = {pid:copy.deepcopy(t.pending(pid)) for pid in (a,b)}
        assert originals[a]["thinking_effort"] == "min"
        assert originals[b]["thinking_effort"] == "extended" and t.count("submit") == 2
        control.set_profile(a, "thinking_effort", '"max"')
        assert t.pending(a) == originals[a] and t.pending(b) == originals[b]
        # Reconstruct from durable JSON after losing the transport's ACK.
        assert json.loads(store.state_path().read_text())["profiles"][a]["pending"] == originals[a]
        with patch.object(daemon, "native_command", side_effect=native):
            daemon.tick(200)
            assert t.count("submit") == 2
            t.uncertain = False
            t.reply(a); daemon.tick(202); daemon.tick(204)
        assert t.pending(a)["thinking_effort"] == "max" and t.count("submit") == 3
        assert t.pending(b)["user_message_id"] == originals[b]["user_message_id"]
        assert t.pending(b)["thinking_effort"] == "extended"

    with environment():
        pid = profile("Unsupported level"); t = Transport()
        control.set_profile(pid, "thinking_effort", '"xhigh"')
        def unavailable(op, **data):
            if op == "preflight": raise RuntimeError("THINKING_EFFORT_UNAVAILABLE")
            return t(op, **data)
        with patch.object(daemon, "native_command", side_effect=unavailable): daemon.tick(100)
        item = store.read_snapshot()[1]["profiles"][pid]
        assert item["pending"] is None and item["prompts_sent"] == 0 and t.count("submit") == 0
        assert item["status"] == "thinking_unavailable" and "Choose Auto" in item["status_detail"]
        control.set_profile(pid, "thinking_effort", '"auto"')
        with patch.object(daemon, "native_command", side_effect=t): daemon.tick(200)
        assert t.pending(pid)["thinking_effort"] == "auto" and "model" not in t.pending(pid)
        assert not store.read_snapshot()[1]["profiles"][pid]["status_detail"]
        assert t.count("submit") == 1

    with environment():
        pid = profile("Changed during preflight"); t = Transport()
        control.set_profile(pid, "thinking_effort", '"standard"')
        def edited(op, **data):
            if op == "preflight":
                control.set_profile(pid, "thinking_effort", '"auto"')
                return {"ready":True, "model":"chat-thinking", "thinking_effort":"standard"}
            return t(op, **data)
        with patch.object(daemon, "native_command", side_effect=edited): daemon.tick(100)
        assert t.pending(pid) is None and t.count("submit") == 0
        with patch.object(daemon, "native_command", side_effect=t): daemon.tick(102)
        assert t.pending(pid)["thinking_effort"] == "auto" and t.count("submit") == 1

    subprocess.run(["node", "scripts/test-hadalis-native-thinking.mjs"],
                   cwd=Path(__file__).resolve().parents[1], check=True, timeout=15)
    print("PASS: legacy Auto, profile isolation, durable effort, edit/restart safety, unsupported preflight and native request contract")


if __name__ == "__main__": main()
