#!/usr/bin/env python3
"""WAIT_RESULT honors rotation, limits and intervals after preserving evidence."""
from unittest.mock import patch
from automation_test_helpers import environment,profile,Transport,daemon,control,store


def main():
    scenarios = [
        ({"rotate_after_iterations":1}, "rotating", "rotation", 104),
        ({"prompt_limit":1}, "completed", None, 104),
        ({"iteration_limit":1}, "completed", None, 104),
        ({"mode":"interval","interval_seconds":60}, "scheduled", "new", 104),
        ({"mode":"duration","duration_seconds":60,"duration_action":"pause"}, "paused", None, 162),
        ({"mode":"duration","duration_seconds":60,"duration_action":"rotate"}, "rotating", "rotation", 162),
    ]
    for settings, status, request, at in scenarios:
        with environment():
            pid=profile("Bounded workflow");other=profile("Independent");t=Transport()
            for key,value in settings.items():
                control.set_profile(pid,key,__import__('json').dumps(value))
            with patch.object(daemon,"native_command",side_effect=t):
                daemon.tick(100);original=t.pending(pid).copy()
                t.reply(pid,"HADALIS_CHECKPOINT:{\"phase\":\"test\",\"next\":\"inspect\"}\nHADALIS_LOOP:WAIT_RESULT JOB-boundary")
                daemon.tick(102)
                assert store.read_snapshot()[1]["profiles"][pid]["job_id"]=="JOB-boundary"
                assert t.count("submit")==2
                payload={"job":"JOB-boundary","profile_id":pid,"status":"passed","actions":[{
                    "kind":"exec","exit_code":0,"evidence_id":"JOB-boundary:0","source_sha":"a"*40}]}
                with patch.object(daemon,"job_result",return_value=payload):daemon.tick(at)
                state=store.read_snapshot()[1];item=state["profiles"][pid]
                assert item["status"]==status and item["request"]==request
                assert item["last_job_id"]=="JOB-boundary" and item["job_evidence"]==["JOB-boundary:0"]
                assert item["checkpoint"]["phase"]=="test" and state["profiles"][other]["desired"]=="run"
                if request=="rotation":
                    daemon.tick(at+2)
                    assert t.pending(pid)["conversation_id"]!=original["conversation_id"]
                    assert t.pending(pid)["operation"]=="rotation"
                    assert store.read_snapshot()[1]["profiles"][pid]["chat_iterations"]==0
                    prompt=[data["prompt"] for op,data in t.calls if op=="submit"][-1]
                    assert "JOB-boundary:0" in prompt and '"phase": "test"' in prompt
                elif request=="new":
                    daemon.tick(at+2);assert t.count("submit")==2
                    assert item["next_run_at_unix"]==at+60
                    daemon.tick(at+60);assert t.count("submit")==3
                else:
                    daemon.tick(at+2);assert t.count("submit")==2 and not item["run_active"]
    for owner_action in (None,"pause","stop"):
        with environment():
            pid,other=profile("Recreated workflow"),profile("Original job owner");t=Transport()
            with patch.object(daemon,"native_command",side_effect=t):
                daemon.tick(100);original=t.pending(pid).copy()
                t.reply(pid,'HADALIS_CHECKPOINT:{"phase":"test","next":"inspect"}\nHADALIS_LOOP:WAIT_RESULT JOB-foreign')
                daemon.tick(102)
                payload={"job":"JOB-foreign","profile_id":other,"status":"passed","actions":[{"evidence_id":"JOB-foreign:0"}]}
                def received(_job):
                    # Owner controls may arrive while the result read is in
                    # flight; reconciliation must check them inside its lock.
                    if owner_action:control.profile_action(owner_action,pid)
                    return payload
                with patch.object(daemon,"job_result",side_effect=received):daemon.tick(104)
                state=store.read_snapshot()[1];item=state["profiles"][pid]
                assert item["job_id"] is None and item["last_job_id"] is None
                assert item["job_evidence"]==[] and item["job_summary"] is None
                assert item["checkpoint"]["phase"]=="test" and item["iterations"]==1
                assert item["recovery"]=={"kind":"response_protocol","code":"foreign_job_owner","job_id":"JOB-foreign","response_message_id":item["response_message_id"]}
                assert (store.state_dir()/"responses"/pid/(original["user_message_id"]+".json")).exists()
                assert state["profiles"][other]["desired"]=="run"
                assert item["desired"]==("stopped" if owner_action=="stop" else "paused")
                assert item["status"]==("idle" if owner_action=="stop" else "paused" if owner_action else "evidence_required")
                daemon.tick(106);assert t.count("submit")==2
                if owner_action is None:
                    guard={k:item[k] for k in ("status","command_seq","response_message_id")}
                    control.profile_action("resume",pid,expected_recovery=guard)
                    daemon.tick(108);assert t.count("submit")==3
                    assert t.pending(pid)["user_message_id"]!=original["user_message_id"]
                    assert t.pending(pid)["conversation_id"]==original["conversation_id"]
                    prompt=[v["prompt"] for op,v in t.calls if op=="submit"][-1]
                    assert "JOB-foreign" in prompt and "do not re-execute or reuse that job" in prompt
                    assert "Managed profile ID: "+pid in prompt
    print("PASS: WAIT_RESULT boundaries/provenance, isolated foreign-job rejection, preserved owner controls and guarded correction without result adoption or replay")


if __name__=="__main__":main()
