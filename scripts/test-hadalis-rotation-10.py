#!/usr/bin/env python3
"""Synthetic 10-completed-turn rotation: no Desktop, network or real profiles."""
from unittest.mock import patch
import uuid

from automation_test_helpers import environment, profile, Transport, daemon, control, store
from automation.manager.model import limit_decision


def set_profile_context(pid, count, *, checkpoint=True, job=None):
    def apply(c, s):
        item = s["profiles"][pid]
        item.update(desired="run", run_active=True, request="continuation",
            status="continuing", pending=None, job_id=job,
            iterations=42+count, chat_iterations=count, last_job_id="JOB-previous",
            response_message_id=str(uuid.uuid4()),
            checkpoint={"phase":"verified", "summary":"Already committed work",
                        "next":"Inspect current dev and continue"} if checkpoint else None,
            session={"conversation_id":str(uuid.uuid4()), "project_id":"project-fixture"})
    store.change_state(apply)


def state(pid):
    return store.read_snapshot()[1]["profiles"][pid]


def verify_normal_threshold():
    with environment():
        a, b = profile("Mega synthetic"), profile("Wull synthetic")
        for pid in (a,b):
            control.set_profile(pid, "mode", '"continuous"')
            control.set_profile(pid, "rotate_after_iterations", "10")
        set_profile_context(a, 9)
        set_profile_context(b, 4)
        c,s,issues = store.read_snapshot()
        assert not issues
        assert limit_decision(next(p for p in c["profiles"] if p["id"] == a),state(a),100) is None
        store.change_state(lambda c,s: daemon._advance(c,s,a,100))
        assert state(a)["request"] == "continuation"
        store.change_state(lambda c,s:s["profiles"][a].update(chat_iterations=10))
        assert limit_decision(next(p for p in c["profiles"] if p["id"] == a),state(a),102) == "rotate"
        old_chat = state(a)["session"]["conversation_id"]
        old_response=state(a)["response_message_id"]
        store.change_state(lambda c,s:daemon._advance(c,s,a,102))
        assert state(a)["request"]=="rotation" and state(a)["status"]=="rotating"
        assert state(b)["request"]=="continuation" and state(b)["chat_iterations"]==4
        t=Transport()
        cfg,runtime,issues=store.read_snapshot()
        with patch.object(daemon, "native_command", side_effect=t):
            daemon._submit(cfg,runtime,a,104)
        item=state(a)
        assert item["chat_iterations"]==0
        assert item["pending"]["kind"]=="rotation"
        assert item["session"]["conversation_id"]!=old_chat
        assert item["pending"]["parent_message_id"]!=old_response
        assert t.count("cursor")==0 and t.count("submit")==1
        prompt=next(data["prompt"] for op,data in t.calls if op=="submit")
        assert "Profile objective" in prompt
        assert "Durable profile checkpoint" in prompt
        assert "Already committed work" in prompt
        assert "JOB-previous" in prompt
        assert state(b)["session"]["conversation_id"]!=item["session"]["conversation_id"]


def verify_wait_result_and_timeout_rotation():
    with environment():
        a=profile("Waiting at threshold")
        control.set_profile(a, "mode", '"continuous"')
        control.set_profile(a, "rotate_after_iterations", "10")
        control.set_profile(a, "rotate_on_cursor_timeout", "true")
        set_profile_context(a,10,job="JOB-current")
        assert state(a)["request"]=="continuation"
        # A tenth WAIT_RESULT does not rotate until the worker's receipt
        # is verified and its job has been cleared.
        def complete_worker(c,s):
            cur=s["profiles"][a]
            assert cur["job_id"] == "JOB-current"
            cur.update(job_id=None,last_job_id="JOB-current",last_result="passed")
            daemon._advance(c,s,a,200)
        store.change_state(complete_worker)
        assert state(a)["request"]=="rotation"
        assert state(a)["job_id"] is None
        assert state(a)["last_job_id"]=="JOB-current"
        assert state(a)["cursor_timeout_streak"]==0
        # Rotation does not call cursor on the old conversation, so a
        # timeout-triggered rotate and the tenth-iteration rotate converge.


def verify_pause_and_existing_limits():
    with environment():
        a=profile("Pause wins")
        control.set_profile(a, "mode", '"continuous"')
        control.set_profile(a, "rotate_after_iterations", "10")
        set_profile_context(a,10)
        control.profile_action("pause",a)
        store.change_state(lambda c,s:daemon._advance(c,s,a,220))
        assert state(a)["desired"]=="paused"
        assert state(a)["request"] is None
        assert state(a)["chat_iterations"]==10
        b=profile("Stop limit wins")
        control.set_profile(b, "mode", '"continuous"')
        control.set_profile(b, "rotate_after_iterations", "10")
        control.set_profile(b, "iteration_limit", "1")
        set_profile_context(b,10)
        store.change_state(lambda c,s:s["profiles"][b].update(run_start_iterations=50))
        store.change_state(lambda c,s:daemon._advance(c,s,b,221))
        assert state(b)["desired"]=="stopped"
        assert state(b)["request"] is None


if __name__=="__main__":
    verify_normal_threshold()
    verify_wait_result_and_timeout_rotation()
    verify_pause_and_existing_limits()
    print("PASS: 10-turn scoped rotation, checkpoint and job preservation, pause precedence, no old-chat replay")
