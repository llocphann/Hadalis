#!/usr/bin/env python3
"""Synthetic verified-turn cursor timeout fallback; never touches real Desktop."""
from unittest.mock import patch
import uuid

from automation_test_helpers import environment, profile, Transport, daemon, store, control


def set_ready(pid, *, context=True):
    def mutate(config, state):
        item = state["profiles"][pid]
        item.update(desired="run", run_active=True, pending=None, job_id=None,
            request="continuation", poll_errors=0, cursor_timeout_streak=0,
            session={"conversation_id":str(uuid.uuid4()), "project_id":"project-fixture"},
            response_message_id=str(uuid.uuid4()),
            checkpoint={"phase":"verified", "summary":"Committed repository effects",
                        "next":"Inspect latest dev and worker receipts"} if context else None,
            last_job_id=None)
    store.change_state(mutate)


def timeout(pid, now, *, pending=None):
    daemon._observe_failure(pid, now,
        daemon.NativeOperationError({"code":"DESKTOP_OPERATION_TIMEOUT",
            "resource":"conversation"},"cursor"), pending=pending)


def snapshot(pid):
    return store.read_snapshot()[1]["profiles"][pid]


def test_scoped_fallback():
    with environment():
        a, b = profile("Opted cursor"), profile("Unrelated cursor")
        control.set_profile(a, "mode", '"continuous"')
        control.set_profile(a, "rotate_on_cursor_timeout", "true")
        control.set_profile(b, "mode", '"continuous"')
        set_ready(a)
        set_ready(b)
        chat=snapshot(a)["session"]["conversation_id"]
        for idx,now in enumerate((100,140),1):
            timeout(a,now)
            item=snapshot(a)
            assert item["cursor_timeout_streak"]==idx
            assert item["request"]=="continuation"
            assert item["pending"] is None
        timeout(a,230)
        item=snapshot(a)
        assert item["cursor_timeout_streak"]==0
        assert item["status"]=="rotating"
        assert item["request"]=="rotation"
        assert item["next_run_at_unix"]>=530
        assert snapshot(b)["request"]=="continuation"
        assert snapshot(b)["cursor_timeout_streak"]==0
        events=[e["kind"] for e in store.read_snapshot()[1]["events"]]
        assert events.count("cursor_timeout_rotation")==1
        # The next action uses a *new* project conversation; it never
        # replays/reattaches the old conversation's last response or prompt.
        t=Transport()
        config,state,issues=store.read_snapshot()
        assert not issues
        with patch.object(daemon,"native_command",side_effect=t):
            daemon._submit(config,state,a,530)
        pending=snapshot(a)["pending"]
        assert pending is not None
        assert pending["kind"]=="rotation"
        assert pending["conversation_id"] is not None
        assert pending["conversation_id"]!=chat
        assert pending["parent_message_id"]!=snapshot(a)["response_message_id"]
        assert t.count("cursor")==0
        assert t.count("submit")==1
        submitted=next(args for op,args in t.calls if op=="submit")
        assert "Durable profile checkpoint" in submitted["prompt"]
        assert "Profile objective" in submitted["prompt"]


def test_fail_closed_and_streak_reset():
    with environment():
        a,b=profile("Not opted in"),profile("No verified context")
        control.set_profile(a,"mode",'"continuous"')
        control.set_profile(b,"mode",'"continuous"')
        control.set_profile(b,"rotate_on_cursor_timeout","true")
        set_ready(a)
        set_ready(b,context=False)
        for now in (100,160,230):
            timeout(a,now)
            timeout(b,now)
        assert snapshot(a)["request"]=="continuation"
        assert snapshot(b)["request"]=="continuation"
        assert snapshot(a)["cursor_timeout_streak"]==3
        assert snapshot(b)["cursor_timeout_streak"]==3
        # A non-cursor error breaks the consecutive timeout sequence.
        daemon._observe_failure(b,300,RuntimeError("different failure"))
        assert snapshot(b)["cursor_timeout_streak"]==0
        # An explicit owner pause always wins, even if the cursor keeps timing out.
        control.set_profile(a,"rotate_on_cursor_timeout","true")
        control.profile_action("pause",a)
        timeout(a,330)
        assert snapshot(a)["desired"]=="paused"
        assert snapshot(a)["request"]!="rotation"
        assert snapshot(a)["cursor_timeout_streak"]==3
        # A pending/uncertain submission must never be abandoned or rotated.
        dummy={"user_message_id":str(uuid.uuid4()),"conversation_id":snapshot(b)["session"]["conversation_id"]}
        store.change_state(lambda c,s:s["profiles"][b].update(pending=dummy,
            cursor_timeout_streak=2))
        timeout(b,340,pending=dummy)
        assert snapshot(b)["pending"]["user_message_id"]==dummy["user_message_id"]
        assert snapshot(b)["request"]=="continuation"


if __name__=="__main__":
    test_scoped_fallback()
    test_fail_closed_and_streak_reset()
    print("PASS: typed cursor timeout fallback is scoped, bounded, verified-turn-only and never replays pending work")
