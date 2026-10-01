#!/usr/bin/env python3
"""Bound real API polling and recover rate limits without replaying work."""
import json
from pathlib import Path
import subprocess
import uuid
from unittest.mock import patch

from automation_test_helpers import environment, profile, Transport, daemon, store, control


def main():
    production_cadence = daemon.CHAT_POLL_SECONDS
    production_spacing = daemon.TRANSPORT_POLL_SPACING_SECONDS
    assert 15 <= production_cadence <= 120
    assert 1 <= production_spacing <= 30
    subprocess.run(["node", "--input-type=module", "-e", r'''
import assert from "node:assert/strict";
import {operationErrorCode} from "./automation/chat_bridge/native_errors.mjs";
assert.equal(operationErrorCode({status:429}), "DESKTOP_RATE_LIMITED");
assert.equal(operationErrorCode({message:'page.evaluate: qK: {"detail":"Too many requests"}'}), "DESKTOP_RATE_LIMITED");
assert.equal(operationErrorCode({message:"HTTP 429"}), "DESKTOP_RATE_LIMITED");
assert.equal(operationErrorCode({message:"GitHub plugin capability unavailable"}), "GITHUB_PLUGIN_UNAVAILABLE");
assert.equal(operationErrorCode({message:"unsupported Desktop transport"}), "DESKTOP_CAPABILITY_UNAVAILABLE");
assert.equal(operationErrorCode({message:"PRIVATE_CANARY auth body"}), "DESKTOP_OPERATION_UNAVAILABLE");
'''], cwd=Path(__file__).resolve().parents[1], check=True, timeout=10)

    # The old fixed-code CLI and the new private HTTP observation contract both
    # work. Unknown fields, raw bodies and timeout command text never persist.
    for stderr, expected in [
        ('DESKTOP_RATE_LIMITED', {"code":"DESKTOP_RATE_LIMITED","operation":"poll"}),
        (json.dumps({"code":"DESKTOP_RATE_LIMITED","http_status":429,"resource":"conversation","body":"PRIVATE_CANARY"}),
         {"code":"DESKTOP_RATE_LIMITED","operation":"poll","http_status":429,"resource":"conversation"}),
        ('PRIVATE_CANARY', {"code":"DESKTOP_OPERATION_UNAVAILABLE","operation":"poll"}),
        (json.dumps({"code":[],"resource":[]}), {"code":"DESKTOP_OPERATION_UNAVAILABLE","operation":"poll"}),
    ]:
        with patch.object(daemon.subprocess,"run",return_value=subprocess.CompletedProcess([],1,"",stderr)):
            try:daemon.native_command("poll",pending={})
            except daemon.NativeOperationError as exc:
                assert exc.observation == expected and "PRIVATE_CANARY" not in str(exc)
            else:raise AssertionError("native failure became success")
    with patch.object(daemon.subprocess,"run",side_effect=subprocess.TimeoutExpired("PRIVATE_CANARY",45)):
        try:daemon.native_command("poll",pending={})
        except daemon.NativeOperationError as exc:
            assert exc.observation == {"code":"DESKTOP_OPERATION_TIMEOUT","operation":"poll"}
        else:raise AssertionError("timeout became success")

    with environment(), patch.object(daemon, "CHAT_POLL_SECONDS", production_cadence):
        a, b = profile("Wull"), profile("Mega")
        t = Transport()
        with patch.object(daemon, "native_command", side_effect=t):
            daemon.tick(100)
            for now in range(102, 100 + production_cadence, 2):
                daemon.tick(now)
            assert t.count("poll") == 0
            daemon.tick(100 + production_cadence)
            assert t.count("poll") == 2
            state = store.read_snapshot()[1]
            for pid in (a, b):
                assert state["profiles"][pid]["pending"]["poll_after_unix"] == 100 + 2 * production_cadence
            daemon.tick(500)
            for pid in (a, b):
                assert t.pending(pid)["poll_after_unix"] == 500 + min(120, 2 * production_cadence)
            assert t.count("submit") == 2

    with environment():
        a, b, worker = profile("Limited"), profile("Cached"), profile("Worker")
        t = Transport()
        with patch.object(daemon, "native_command", side_effect=t):
            daemon.tick(100)
        original = t.pending(a).copy()
        cached = t.pending(b).copy()
        worker_pending = t.pending(worker).copy()
        t.reply(b)
        t.reply(worker, "HADALIS_LOOP:WAIT_RESULT JOB-local")
        daemon._observe_failure(a, 102, daemon.NativeOperationError({"code":"DESKTOP_RATE_LIMITED",
            "resource":"conversation","http_status":429,"body":"PRIVATE_CANARY"},"poll"), pending=original)
        # A crash left a fsynced reply, so no Desktop request is needed for B.
        store._write(store.state_dir()/"responses"/b/(cached["user_message_id"]+".json"), {
            "user_message_id":cached["user_message_id"], "conversation_id":cached["conversation_id"],
            "response":{"message_id":str(uuid.uuid5(uuid.NAMESPACE_URL,cached["user_message_id"])), "text":"HADALIS_LOOP:CONTINUE"}, "at_unix":102})
        store.change_state(lambda c,s:s["profiles"][worker].update(pending=None, job_id="JOB-local", next_job_poll_at_unix=0,
            response_message_id=str(uuid.uuid5(uuid.NAMESPACE_URL,worker_pending["user_message_id"]))))
        job = {"job":"JOB-local", "profile_id":worker, "status":"passed", "actions":[]}
        with patch.object(daemon, "native_command", side_effect=t), patch.object(daemon, "job_result", return_value=job):
            daemon.tick(104)
            state = store.read_snapshot()[1]
            until = 102 + daemon.RATE_LIMIT_SECONDS
            assert state["transport_retry_at_unix"] == until
            assert state["profiles"][a]["pending"]["user_message_id"] == original["user_message_id"]
            assert state["profiles"][a]["status"] == "transport_rate_limited"
            assert state["profiles"][a]["transport_observation"] == {
                "code":"DESKTOP_RATE_LIMITED","operation":"poll","resource":"conversation","http_status":429,"at_unix":102}
            assert "reading the response" in state["profiles"][a]["status_detail"]
            assert "PRIVATE_CANARY" not in store.state_path().read_text()
            assert state["profiles"][b]["iterations"] == 1
            assert state["profiles"][worker]["last_job_id"] == "JOB-local"
            # Normalization and subsequent scheduler ticks preserve cooldown.
            for now in range(106, until, 2):
                daemon.tick(now)
            assert t.count("submit") == 3 and t.count("poll") == 0
            assert json.loads(store.state_path().read_text())["transport_retry_at_unix"] == until
            t.reply(a)
            daemon.tick(until)
            assert store.read_snapshot()[1]["profiles"][a]["iterations"] == 1
            assert t.count("poll") == 1
            assert store.read_snapshot()[1]["profiles"][a]["prompts_sent"] == 1
            assert store.read_snapshot()[1]["profiles"][a]["transport_observation"] is None
            # The other two profiles can now submit independent next steps.
            assert t.count("submit") == 5
    with environment():
        a,b=profile("Stream A"),profile("Stream B");t=Transport()
        with patch.object(daemon,"native_command",side_effect=t):daemon.tick(100)
        identities={pid:t.pending(pid).copy() for pid in (a,b)}
        daemon._observe_failure(a,102,daemon.NativeOperationError(
            {"code":"DESKTOP_RATE_LIMITED","resource":"conversation","http_status":429},"poll"),pending=identities[a])
        t.reply(a);t.reply(b)
        control.profile_action("pause",b)
        local_calls=[]
        def native(op,**data):
            if op=="stream_receipt":
                uid=data["pending"]["user_message_id"];local_calls.append(uid)
                return {"completed":True,"submitted":True,"history_checked":False,"response_source":"managed_stream",
                    "conversation_id":data["pending"]["conversation_id"],"response":{
                        "message_id":str(uuid.uuid5(uuid.NAMESPACE_URL,uid)),"text":t.replies[uid]}}
            return t(op,**data)
        with patch.object(daemon,"native_command",side_effect=native):
            daemon.tick(130);s=store.read_snapshot()[1]
            assert len(local_calls)==2 and t.count("poll")==0 and t.count("submit")==2
            assert s["transport_rate_limit_count"]==1 and s["transport_retry_at_unix"]==102+daemon.RATE_LIMIT_SECONDS
            assert s["profiles"][a]["iterations"]==1 and s["profiles"][b]["desired"]=="paused"
            assert all(s["profiles"][pid]["pending"] is None for pid in (a,b))
            for pid in (a,b):
                receipt=json.loads((store.state_dir()/"responses"/pid/(identities[pid]["user_message_id"]+".json")).read_text())
                assert receipt["response_source"]=="managed_stream"
            daemon.tick(132);assert t.count("submit")==2
            daemon.tick(102+daemon.RATE_LIMIT_SECONDS)
            assert t.count("submit")==3 and t.pending(a)["user_message_id"]!=identities[a]["user_message_id"]
            assert store.read_snapshot()[1]["profiles"][b]["desired"]=="paused"
    with environment():
        pid=profile("Recovered");t=Transport()
        store.change_state(lambda c,s:s["profiles"][pid].update(poll_errors=4,last_error="DESKTOP_RATE_LIMITED"))
        with patch.object(daemon,"native_command",side_effect=t):
            daemon.tick(100)
            item=store.read_snapshot()[1]["profiles"][pid]
            assert item["poll_errors"] == 0 and item["last_error"] == ""
            t.down=True;daemon.tick(102)
            assert t.pending(pid)["poll_after_unix"] == 132

    # Two due profiles consume distinct shared read slots; their generations
    # remain simultaneous and their exact pending identities survive admission.
    with environment(), patch.object(daemon,"TRANSPORT_POLL_SPACING_SECONDS",production_spacing):
        a,b=profile("Paced A"),profile("Paced B");t=Transport()
        with patch.object(daemon,"native_command",side_effect=t):
            daemon.tick(100);assert t.count("submit")==2
            identities={pid:t.pending(pid)["user_message_id"] for pid in (a,b)}
            t.reply(a,"HADALIS_LOOP:DONE");t.reply(b,"HADALIS_LOOP:DONE")
            daemon.tick(102);assert t.count("poll")==1
            state=store.read_snapshot()[1]
            waiting=[pid for pid in (a,b) if state["profiles"][pid]["pending"]]
            assert len(waiting)==1
            pid=waiting[0]
            assert state["profiles"][pid]["pending"]["user_message_id"]==identities[pid]
            assert state["transport_next_poll_at_unix"]==102+production_spacing
            assert json.loads(store.state_path().read_text())["transport_next_poll_at_unix"]==102+production_spacing
            daemon.tick(102+production_spacing-1);assert t.count("poll")==1
            daemon.tick(102+production_spacing);assert t.count("poll")==2
            assert t.count("submit")==2
            assert all(store.read_snapshot()[1]["profiles"][p]["iterations"]==1 for p in (a,b))

    # Repeated 429 retry rounds increase durable backoff; concurrent failures in
    # one round and an isolated successful read cannot reset/amplify it.
    with environment():
        a,b=profile("Rate A"),profile("Rate B");t=Transport()
        with patch.object(daemon,"native_command",side_effect=t):daemon.tick(100)
        def limit(pid,now):
            daemon._observe_failure(pid,now,daemon.NativeOperationError(
                {"code":"DESKTOP_RATE_LIMITED","resource":"conversation","http_status":429},"poll"),pending=t.pending(pid))
        limit(a,102);limit(b,103)
        state=store.read_snapshot()[1]
        assert state["transport_rate_limit_count"]==1
        assert state["transport_retry_at_unix"]==103+daemon.RATE_LIMIT_SECONDS
        for expected in range(2,8):
            now=store.read_snapshot()[1]["transport_retry_at_unix"]
            limit(a,now)
            state=store.read_snapshot()[1]
            count=min(6,expected)
            delay=min(daemon.MAX_RATE_LIMIT_SECONDS,daemon.RATE_LIMIT_SECONDS*2**(count-1))
            assert state["transport_rate_limit_count"]==count
            assert state["transport_retry_at_unix"]==now+delay
            assert json.loads(store.state_path().read_text())["transport_rate_limit_count"]==count
            daemon._poll_succeeded(now+1)
            assert store.read_snapshot()[1]["transport_rate_limit_count"]==count
            with patch.object(daemon,"native_command",side_effect=t):daemon.tick(now+delay-1)
            assert t.count("poll")==0 and t.count("submit")==2
        state=store.read_snapshot()[1];at=state["transport_rate_limit_at_unix"]
        daemon._poll_succeeded(at-1)
        assert store.read_snapshot()[1]["transport_rate_limit_count"]==6
        daemon._poll_succeeded(at+2*daemon.MAX_RATE_LIMIT_SECONDS)
        assert store.read_snapshot()[1]["transport_rate_limit_count"]==0
        legacy=dict(state)
        for key in ("transport_next_poll_at_unix","transport_rate_limit_count","transport_rate_limit_at_unix"):
            legacy.pop(key)
        migrated=store.normalize_state(legacy,store.read_snapshot()[0])
        assert migrated["transport_retry_at_unix"]==state["transport_retry_at_unix"]
        assert migrated["transport_rate_limit_count"]==0
        assert migrated["profiles"][a]["pending"]["user_message_id"]==t.pending(a)["user_message_id"]
    print("PASS: paced independent profile reads, adaptive bounded retry rounds, durable cooldown/admission, local job/cache progress and no prompt replay")


if __name__ == "__main__":
    main()
