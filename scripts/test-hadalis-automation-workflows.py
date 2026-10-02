#!/usr/bin/env python3
"""Evidence-driven generic workflow, isolated malformed config and failed turns."""
import json
from unittest.mock import patch
from automation_test_helpers import environment,profile,Transport,daemon,control,store


def main():
    with environment():
        pid=profile();t=Transport()
        with patch.object(daemon,"native_command",side_effect=t):
            daemon.tick(100);t.reply(pid,"HADALIS_LOOP:WAIT_RESULT JOB-evidence");daemon.tick(102)
            evidence={"job":"JOB-evidence","profile_id":pid,"status":"failed","job_commit":"b"*40,
                "actions":[{"kind":"diagnostics","evidence_id":"JOB-evidence:0","source_sha":"b"*40,"observed_at_unix":102,
                            "stdout":"PRIVATE_PASSWORD=do-not-share","safe_observations":[{"check":"journal","exit_code":0,"error_codes":["qml_import"]}]}]}
            with patch.object(daemon,"job_result",return_value=evidence):daemon.tick(104)
            daemon.tick(106)
            prompt=[data["prompt"] for op,data in t.calls if op=="submit"][-1]
            assert "qml_import" in prompt and "JOB-evidence:0" in prompt and "do-not-share" not in prompt
            t.reply(pid,'HADALIS_DIAGNOSIS:{"conclusion":"The import is missing","evidence_ids":["JOB-evidence:0"]}\nHADALIS_CHECKPOINT:{"phase":"fix","next":"validate","evidence_ids":["JOB-evidence:0"]}\nHADALIS_LOOP:CONTINUE')
            daemon.tick(108);assert store.read_snapshot()[1]["profiles"][pid]["checkpoint"]["phase"]=="fix"
            daemon.tick(110)
            t.reply(pid,'HADALIS_DIAGNOSIS:{"conclusion":"Unproven cause","evidence_ids":["invented"]}\nHADALIS_LOOP:CONTINUE')
            daemon.tick(112);item=store.read_snapshot()[1]["profiles"][pid]
            assert item["status"]=="evidence_required" and item["pending"] is None and item["desired"]=="paused"
            assert "unobserved worker evidence IDs" in item["last_error"]
            assert item["recovery"]["code"] == "unsupported_diagnosis"
            count=t.count("submit");daemon.tick(114);assert t.count("submit")==count
            guard={k:item[k] for k in ["status","command_seq","response_message_id"]}
            # A racing owner Stop/Pause cannot be replaced by monitor recovery.
            for action in ("stop","pause"):
                control.profile_action(action,pid)
                try:control.profile_action("resume",pid,expected_recovery=guard)
                except ValueError as exc:assert "changed after recovery inspection" in str(exc)
                else:raise AssertionError("stale recovery overrode owner control")
                assert store.read_snapshot()[1]["profiles"][pid]["desired"] == ("stopped" if action=="stop" else "paused")
            # A deliberate owner Resume uses a new user identity and carries a
            # correction context, while the consumed response remains intact.
            with patch.object(control,"_ensure_runtime_services"),patch.object(control,"_await_dispatch"):
                control.profile_action("resume",pid)
            daemon.tick(116)
            submit=[data for op,data in t.calls if op=="submit"][-1]
            assert "Correct the protocol" in submit["prompt"] and "do not replay the completed turn" in submit["prompt"]
            assert "JOB-evidence:0" in submit["prompt"]
            t.reply(pid,"Repository finding with a normal source citation.\nHADALIS_LOOP:DONE")
            daemon.tick(118)
            assert store.read_snapshot()[1]["profiles"][pid]["recovery"] is None
    with environment():
        pid=profile("Guarded recovery");t=Transport()
        with patch.object(daemon,"native_command",side_effect=t):
            daemon.tick(100);original=t.pending(pid).copy()
            t.reply(pid,'HADALIS_DIAGNOSIS:{"conclusion":"Repository finding","evidence_ids":["turn1file0"]}\nHADALIS_LOOP:CONTINUE')
            daemon.tick(102);daemon.tick(104)
            item=store.read_snapshot()[1]["profiles"][pid]
            guard={k:item[k] for k in ["status","command_seq","response_message_id"]}
            control.profile_action("resume",pid,expected_recovery=guard)
            daemon.tick(106)
            assert t.pending(pid)["user_message_id"] != original["user_message_id"]
            assert t.count("submit") == 2 and t.count("resume") == 0
            receipt=store.state_dir()/"responses"/pid/(original["user_message_id"]+".json")
            assert json.loads(receipt.read_text())["response"]["message_id"] == guard["response_message_id"]
            t.reply(pid,"Repository finding with its GitHub citation.\nHADALIS_LOOP:DONE")
            daemon.tick(108)
            assert store.read_snapshot()[1]["profiles"][pid]["recovery"] is None
    with environment():
        pid=profile("Fresh connector session");t=Transport()
        with patch.object(daemon,"native_command",side_effect=t):
            daemon.tick(100);original=t.pending(pid).copy()
            t.reply(pid,"HADALIS_LOOP:CONNECTOR_BLOCKED GITHUB")
            daemon.tick(102)
            item=store.read_snapshot()[1]["profiles"][pid]
            guard={k:item[k] for k in ["status","command_seq","response_message_id"]}
            receipt=store.state_dir()/"responses"/pid/(original["user_message_id"]+".json")
            retained=receipt.read_bytes()
            control.profile_action("restart",pid,expected_recovery=guard)
            daemon.tick(104);new=t.pending(pid).copy()
            assert new["conversation_id"]!=original["conversation_id"]
            assert new["user_message_id"]!=original["user_message_id"]
            assert t.count("submit")==2 and receipt.read_bytes()==retained
            try:control.profile_action("restart",pid,expected_recovery=guard)
            except ValueError as exc:assert "changed after recovery inspection" in str(exc)
            else:raise AssertionError("recovery guard reused against pending turn")
            daemon.tick(106);assert t.count("submit")==2
            t.reply(pid,"HADALIS_LOOP:CONNECTOR_BLOCKED GITHUB");daemon.tick(108)
            guard={k:store.read_snapshot()[1]["profiles"][pid][k] for k in guard}
            for action in ("stop","pause"):
                control.profile_action(action,pid)
                try:control.profile_action("restart",pid,expected_recovery=guard)
                except ValueError as exc:assert "changed after recovery inspection" in str(exc)
                else:raise AssertionError("stale fresh-session recovery overrode owner control")
            assert receipt.read_bytes()==retained
    with environment():
        good=profile("Good");bad=profile("Malformed");t=Transport()
        original=store.read_snapshot()[0]
        for p in original["profiles"]:
            if p["id"]==bad:p["mode"]="bad-mode"
        store._write(store.config_path(),original)
        store.change_state(lambda c,s:s["profiles"][bad].update(pending={"prepared_at_unix":80,"response_action_count":3}))
        with patch.object(daemon,"native_command",side_effect=t):daemon.tick(100)
        assert store.read_snapshot()[1]["profiles"][good]["pending"]
        assert store.read_snapshot()[1]["profiles"][bad]["pending"]["response_action_count"]==3
        assert json.loads(store.config_path().read_text())["profiles"][-1]["mode"]=="bad-mode", "quarantine must preserve raw config"
    with environment():
        pid=profile();t=Transport()
        with patch.object(daemon,"native_command",side_effect=t):daemon.tick(100)
        original=t.pending(pid)
        def native(op,**data):
            if op=="poll":return {"completed":False,"submitted":True,"terminal_failed":True,"conversation_id":original["conversation_id"],"terminal_failure_source":"conversation_stream_status","server_stream_status":"FAILURE"}
            return t(op,**data)
        with patch.object(daemon,"native_command",side_effect=native):
            daemon.tick(102);item=store.read_snapshot()[1]["profiles"][pid]
            assert item["pending"] is None and item["request"]=="recovery"
            assert item["failed_turn"]["source"]=="conversation_stream_status"
            receipt=json.loads((store.state_dir()/"failed-turns"/pid/(original["user_message_id"]+".json")).read_text())
            assert receipt["server_stream_status"]=="FAILURE" and receipt["pending"]["user_message_id"]==original["user_message_id"]
            daemon.tick(132)
            assert t.pending(pid)["user_message_id"]!=original["user_message_id"]
            assert t.pending(pid)["conversation_id"]!=original["conversation_id"]
            assert t.count("submit")==2
            assert "new recovery step" in [d["prompt"] for op,d in t.calls if op=="submit"][-1]
    with environment():
        a,b=profile("Superseded"),profile("Independent");t=Transport()
        with patch.object(daemon,"native_command",side_effect=t):daemon.tick(100)
        original=t.pending(a).copy()
        def native(op,**data):
            if op=="poll" and data["pending"]["user_message_id"]==original["user_message_id"]:
                return {"completed":False,"submitted":True,"superseded":True,
                    "successor_user_message_id":"human-turn","conversation_id":original["conversation_id"]}
            return t(op,**data)
        t.reply(b)
        with patch.object(daemon,"native_command",side_effect=native):
            daemon.tick(162);state=store.read_snapshot()[1]
            assert state["profiles"][a]["desired"]=="paused" and state["profiles"][a]["status"]=="session_changed"
            assert state["profiles"][a]["pending"]["user_message_id"]==original["user_message_id"]
            assert state["profiles"][b]["iterations"]==1
            daemon.tick(164);assert t.count("submit")==3 and t.count("resume")==0
            control.profile_action("stop",a);daemon.tick(222)
            assert store.read_snapshot()[1]["profiles"][a]["desired"]=="stopped"
            assert t.count("resume")==0 and t.count("submit")==3
    # A completed response with no valid loop directive is not a transport
    # failure. Owner Resume must keep the finished response, use a fresh user
    # message on its existing verified branch, and state the exact protocol.
    with environment():
        pid=profile("Protocol repair");t=Transport()
        with patch.object(daemon,"native_command",side_effect=t):
            daemon.tick(100)
            original=t.pending(pid).copy()
            t.reply(pid,"Completed the repository review, but omitted the final control marker.")
            daemon.tick(102)
            before=store.read_snapshot()[1]["profiles"][pid]
            assert before["status"]=="evidence_required"
            assert before["recovery"]["code"]=="invalid_directive"
            assert before["desired"]=="paused" and before["pending"] is None
            saved_response=before["response_message_id"]
            assert saved_response
            with patch.object(control,"_ensure_runtime_services"),patch.object(control,"_await_dispatch"):
                control.profile_action("resume",pid)
            daemon.tick(104)
            after=store.read_snapshot()[1]["profiles"][pid]
            assert after["pending"] and after["pending"]["user_message_id"]!=original["user_message_id"]
            assert after["pending"]["conversation_id"]==original["conversation_id"]
            assert after["pending"]["parent_message_id"]==saved_response
            assert t.count("submit")==2
            correction=[data for op,data in t.calls if op=="submit"][-1]["prompt"]
            assert "Protocol repair required" in correction
            assert "EXACTLY ONE" in correction and "as its last line" in correction
            assert "do not repeat them" in correction
            assert "do not invent job IDs" in correction

    print("PASS: generic evidence/checkpoints, quarantine, failure recovery and isolated superseded turns without prompt replay or stream reattachment")


if __name__=="__main__":main()
