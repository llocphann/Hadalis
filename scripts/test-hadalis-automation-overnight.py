#!/usr/bin/env python3
"""Deterministic overnight automation protocol-repair regressions.

Synthetic config, state and transport only. No real Desktop, Git mutations,
external accounts, services, network calls or live message submissions.
"""
from automation_test_helpers import environment, profile, Transport, daemon, control, store
from unittest.mock import patch


def enabled(name):
    pid = profile(name)
    control.set_profile(pid, "mode", '"continuous"')
    control.set_profile(pid, "auto_protocol_recovery", "true")
    return pid


def snapshot(pid):
    return store.read_snapshot()[1]["profiles"][pid]


def test_benign_repair_without_replay():
    with environment():
        a, b = enabled("Auto protocol"), profile("Unrelated")
        t = Transport()
        with patch.object(daemon, "native_command", side_effect=t):
            daemon.tick(100)
            original_a = t.pending(a).copy()
            original_b = t.pending(b).copy()
            t.reply(a, "A complete repository review with a missing directive")
            t.reply(b, "HADALIS_LOOP:CONTINUE")
            daemon.tick(102)
            item = snapshot(a)
            assert item["desired"] == "run"
            assert item["status"] == "recovering_protocol"
            assert item["protocol_repair_attempts"] == 1
            assert item["recovery"]["code"] == "invalid_directive"
            assert item["pending"] is None
            saved_reply = item["response_message_id"]
            chat = item["session"]["conversation_id"]
            assert saved_reply and chat == original_a["conversation_id"]
            assert snapshot(b)["iterations"] == 1
            daemon.tick(104)  # Independent B can continue during A's repair delay.
            assert t.pending(b)["user_message_id"] != original_b["user_message_id"]
            count_a = sum(v == chat for v in t.messages.values())
            daemon.tick(221)
            assert sum(v == chat for v in t.messages.values()) == count_a
            # A scheduler reboot is modeled by a separate durable state read.
            assert snapshot(a)["protocol_repair_attempts"] == 1
            daemon.tick(222)
            fresh = t.pending(a)
            assert fresh["user_message_id"] != original_a["user_message_id"]
            assert fresh["conversation_id"] == chat
            assert fresh["parent_message_id"] == saved_reply
            assert sum(v == chat for v in t.messages.values()) == count_a + 1
            correction = [
                c["prompt"] for op, c in t.calls
                if op == "submit" and c.get("conversation_id") == chat
            ][-1]
            assert "Protocol repair required" in correction
            assert "EXACTLY ONE" in correction
            assert "do not repeat them" in correction
            t.reply(a, "Correction applied to protocol only.\nHADALIS_LOOP:CONTINUE")
            daemon.tick(224)
            after = snapshot(a)
            assert after["protocol_repair_attempts"] == 0
            assert after["recovery"] is None
            assert after["desired"] == "run"
            assert after["iterations"] == 2


def test_retry_budget_and_independent_stop():
    with environment():
        a = enabled("Bounded repair")
        t = Transport()
        with patch.object(daemon, "native_command", side_effect=t):
            daemon.tick(100)
            t.reply(a, "No directive")
            daemon.tick(102)
            assert snapshot(a)["protocol_repair_attempts"] == 1
            daemon.tick(222)
            t.reply(a, "Still missing")
            daemon.tick(224)
            assert snapshot(a)["protocol_repair_attempts"] == 2
            daemon.tick(463)
            assert t.count("submit") == 2
            daemon.tick(464)
            t.reply(a, "Third malformed final")
            daemon.tick(466)
            item = snapshot(a)
            assert item["desired"] == "paused"
            assert item["status"] == "evidence_required"
            assert item["recovery"]["code"] == "invalid_directive"
            assert item["protocol_repair_attempts"] == 2
            assert t.count("submit") == 3
            daemon.tick(3000)
            assert t.count("submit") == 3
            events = [x["kind"] for x in store.read_snapshot()[1]["events"]]
            assert events.count("protocol_repair_scheduled") == 2
            assert events.count("protocol_repair_exhausted") == 1

    with environment():
        a = enabled("Explicit owner pause")
        t = Transport()
        with patch.object(daemon, "native_command", side_effect=t):
            daemon.tick(100)
            t.reply(a, "Missing")
            daemon.tick(102)
            control.profile_action("pause", a)
            daemon.tick(400)
            assert snapshot(a)["desired"] == "paused"
            assert t.count("submit") == 1


def test_evidence_repair_and_default_fail_closed():
    with environment():
        a = enabled("Evidence repair")
        b = profile("Not opted in")
        t = Transport()
        text = ('HADALIS_DIAGNOSIS:{"conclusion":"unsupported",'
                '"evidence_ids":["unobserved"]}\nHADALIS_LOOP:CONTINUE')
        with patch.object(daemon, "native_command", side_effect=t):
            daemon.tick(100)
            t.reply(a, text)
            t.reply(b, "No directive")
            daemon.tick(102)
            assert snapshot(a)["status"] == "recovering_protocol"
            assert snapshot(a)["recovery"]["code"] == "unsupported_diagnosis"
            assert snapshot(b)["desired"] == "paused"
            assert snapshot(b)["status"] == "evidence_required"
            daemon.tick(222)
            a_chat = snapshot(a)["session"]["conversation_id"]
            correction = [c["prompt"] for op, c in t.calls
                          if op == "submit" and c.get("conversation_id") == a_chat][-1]
            assert "Evidence repair required" in correction
            assert "Ordinary repository conclusions" in correction
            assert "not authorization" in correction


if __name__ == "__main__":
    test_benign_repair_without_replay()
    test_retry_budget_and_independent_stop()
    test_evidence_repair_and_default_fail_closed()
    print("PASS: opt-in bounded overnight protocol recovery, isolation, exhaustion and pause precedence")
