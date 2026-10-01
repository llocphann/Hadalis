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
    assert not issues and config["profiles"][0]["thinking_effort"] == "extended"
    assert config["default_thinking_effort"] == "extended"
    assert config["profiles"][0]["prompt"] == legacy["prompt"]
    config, issues = model.normalize_config({"profiles":[dict(legacy, thinking_effort="auto")],
                                            "default_thinking_effort":"standard"})
    assert not issues and config["profiles"][0]["thinking_effort"] == "standard"
    config, issues = model.normalize_config({"default_thinking_effort":"instant"})
    assert not issues and config["profiles"][0]["thinking_effort"] == "instant"
    config, issues = model.normalize_config({"profiles":[legacy],"default_thinking_effort":[]})
    assert len(issues) == 1 and config["default_thinking_effort"] == "extended"
    source = model.update_profile(model.new_profile("Source"), {"thinking_effort":"extended"})
    assert model.new_profile("Duplicate", copy=source)["thinking_effort"] == "extended"
    for invalid in (None, [], {}, 1, True, "high", "ultra", "private-canary"):
        try: model.update_profile(source, {"thinking_effort":invalid})
        except ValueError as exc: assert str(exc) == "invalid thinking_effort"
        else: raise AssertionError("unsupported profile effort was accepted")

    with environment():
        high = control.create_profile("Default High")["profile_id"]
        control.set_thinking_default("standard")
        config, state, _ = store.read_snapshot()
        assert next(p for p in config["profiles"] if p["id"] == high)["thinking_effort"] == "extended"
        medium = control.create_profile("Default Medium")["profile_id"]
        assert next(p for p in store.read_snapshot()[0]["profiles"] if p["id"] == medium)["thinking_effort"] == "standard"
        duplicate = control.create_profile("Keep High", high)["profile_id"]
        assert next(p for p in store.read_snapshot()[0]["profiles"] if p["id"] == duplicate)["thinking_effort"] == "extended"
        # Exercise the endpoint used by the real Settings button and reload JSON.
        subprocess.run(["python3", "scripts/hadalis-automation-control.py", "thinking-default", "instant"],
                       cwd=Path(__file__).resolve().parents[1],check=True,capture_output=True,timeout=10)
        assert json.loads(store.config_path().read_text())["default_thinking_effort"] == "instant"
        instant = control.create_profile("Default Instant")["profile_id"]
        assert next(p for p in store.read_snapshot()[0]["profiles"] if p["id"] == instant)["thinking_effort"] == "instant"
        for invalid in (None, [], "auto", "high", "private-canary"):
            try: control.set_thinking_default(invalid)
            except ValueError: pass
            else: raise AssertionError("unsupported default was accepted")
        assert store.read_snapshot()[0]["default_thinking_effort"] == "instant"

    with environment():
        a, b = profile("Light chat"), profile("Deep chat")
        control.set_profile(a, "thinking_effort", '"instant"')
        control.set_profile(b, "thinking_effort", '"extended"')
        t = Transport()
        def native(op, **data):
            if op == "preflight":
                assert data["requires_github"] is False
                effort = data["thinking_effort"]
                return {"ready":True, "model":"chat-instant" if effort == "instant" else "chat-thinking", "thinking_effort":effort}
            if op == "cursor": return {**t(op, **data), "model":"chat-thinking"}
            if op == "submit":
                durable = [i["pending"] for i in store.read_snapshot()[1]["profiles"].values()
                           if (i.get("pending") or {}).get("user_message_id") == data["user_message_id"]]
                assert len(durable) == 1 and durable[0]["model"] == data["model"]
                assert durable[0]["thinking_effort"] == data["thinking_effort"]
            return t(op, **data)
        t.uncertain = True
        with patch.object(daemon, "native_command", side_effect=native): daemon.tick(100)
        originals = {pid:copy.deepcopy(t.pending(pid)) for pid in (a,b)}
        assert originals[a]["thinking_effort"] == "instant" and originals[a]["model"] == "chat-instant"
        assert originals[b]["thinking_effort"] == "extended" and t.count("submit") == 2
        control.set_profile(a, "thinking_effort", '"max"')
        control.set_thinking_default("standard")
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
        pid = profile("Legacy pending");t = Transport()
        with patch.object(daemon, "native_command", side_effect=t): daemon.tick(100)
        def old_request(c, s):
            next(p for p in c["profiles"] if p["id"] == pid)["thinking_effort"] = "auto"
            s["profiles"][pid]["pending"]["thinking_effort"] = "auto"
            s["profiles"][pid]["pending"].pop("model", None)
        store.change(old_request)
        original = copy.deepcopy(t.pending(pid))
        assert next(p for p in store.read_snapshot()[0]["profiles"] if p["id"] == pid)["thinking_effort"] == "extended"
        with patch.object(daemon, "native_command", side_effect=t): daemon.tick(200)
        observation_fields = {"poll_after_unix", "resume_after_unix", "resume_attempts", "observation"}
        assert {k:v for k,v in t.pending(pid).items() if k not in observation_fields} == {k:v for k,v in original.items() if k not in observation_fields}
        assert t.count("submit") == 1
        original = copy.deepcopy(t.pending(pid))
        control.set_thinking_default("instant")
        assert t.pending(pid) == original

    with environment():
        pid = profile("Unsupported level"); t = Transport()
        control.set_profile(pid, "thinking_effort", '"xhigh"')
        def unavailable(op, **data):
            if op == "preflight": raise RuntimeError("THINKING_EFFORT_UNAVAILABLE")
            return t(op, **data)
        with patch.object(daemon, "native_command", side_effect=unavailable): daemon.tick(100)
        item = store.read_snapshot()[1]["profiles"][pid]
        assert item["pending"] is None and item["prompts_sent"] == 0 and t.count("submit") == 0
        assert item["status"] == "thinking_unavailable" and "Choose another" in item["status_detail"]
        control.set_profile(pid, "thinking_effort", '"standard"')
        with patch.object(daemon, "native_command", side_effect=t): daemon.tick(200)
        assert t.pending(pid)["thinking_effort"] == "standard" and t.pending(pid)["model"] == "chat-thinking"
        assert not store.read_snapshot()[1]["profiles"][pid]["status_detail"]
        assert t.count("submit") == 1

    with environment():
        pid = profile("Changed during preflight"); t = Transport()
        control.set_profile(pid, "thinking_effort", '"standard"')
        def edited(op, **data):
            if op == "preflight":
                control.set_profile(pid, "thinking_effort", '"instant"')
                return {"ready":True, "model":"chat-thinking", "thinking_effort":"standard"}
            return t(op, **data)
        with patch.object(daemon, "native_command", side_effect=edited): daemon.tick(100)
        assert t.pending(pid) is None and t.count("submit") == 0
        with patch.object(daemon, "native_command", side_effect=t): daemon.tick(102)
        assert t.pending(pid)["thinking_effort"] == "instant" and t.count("submit") == 1

    subprocess.run(["node", "scripts/test-hadalis-native-thinking.mjs"],
                   cwd=Path(__file__).resolve().parents[1], check=True, timeout=15)
    print("PASS: High default, saved new-profile defaults, legacy pending preservation, isolated durable effort, edit/restart safety and native request contract")


if __name__ == "__main__": main()
