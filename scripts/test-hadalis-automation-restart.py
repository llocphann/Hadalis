#!/usr/bin/env python3
"""A Restart is one durable action; WAIT_RESULT always retains its receipt."""
import json
from unittest.mock import patch
from automation_test_helpers import environment, profile, Transport, daemon, control, store


def main():
    with environment():
        pid = profile("Mega")
        t = Transport()
        with patch.object(daemon,"native_command",side_effect=t):
            daemon.tick(100)
            original = t.pending(pid).copy()
            control.profile_action("restart",pid)
            t.reply(pid,"HADALIS_LOOP:CONTINUE")
            daemon.tick(102)
            assert store.read_snapshot()[1]["profiles"][pid]["request"] == "restart"
            daemon.tick(104)
            restarted = t.pending(pid).copy()
            assert restarted["conversation_id"] != original["conversation_id"]
            assert restarted["operation"] == "restart"
            assert store.read_snapshot()[1]["profiles"][pid]["request"] == "continuation"
            t.reply(pid,"HADALIS_LOOP:WAIT_RESULT JOB-after-restart")
            daemon.tick(106)
            assert store.read_snapshot()[1]["profiles"][pid]["job_id"] == "JOB-after-restart"
            control.profile_action("restart",pid)
            with patch.object(daemon,"job_result",return_value=None):
                daemon.tick(108)
            assert t.count("submit") == 2
            assert store.read_snapshot()[1]["profiles"][pid]["job_id"] == "JOB-after-restart"
            assert json.loads((store.state_dir()/"worker/cancellations/JOB-after-restart").read_text())["profile_id"] == pid
            result={"job":"JOB-after-restart","profile_id":pid,"status":"cancelled", "actions":[{"evidence_id":"JOB-after-restart:0","exit_code":-15,"kind":"exec"}]}
            with patch.object(daemon,"job_result",return_value=result):
                daemon.tick(118)
            item=store.read_snapshot()[1]["profiles"][pid]
            assert item["request"] == "restart" and item["last_job_id"] == "JOB-after-restart"
            assert item["job_evidence"] == ["JOB-after-restart:0"]
            daemon.tick(120)
            assert t.count("submit") == 3
            assert t.pending(pid)["conversation_id"] != restarted["conversation_id"]
            assert store.read_snapshot()[1]["profiles"][pid]["request"] == "continuation"

    with environment():
        pid=profile();t=Transport()
        with patch.object(daemon,"native_command",side_effect=t):
            daemon.tick(100)
            control.profile_action("restart",pid)
            # Restart before the pending reply can reveal its local job.
            t.reply(pid,"HADALIS_LOOP:WAIT_RESULT JOB-discovered")
            daemon.tick(102)
            item=store.read_snapshot()[1]["profiles"][pid]
            assert item["job_id"] == "JOB-discovered" and item["request"] == "restart"
            assert (store.state_dir()/"worker/cancellations/JOB-discovered").exists()
            with patch.object(daemon,"job_result",return_value=None):
                daemon.tick(104)
            assert t.count("submit") == 1

    with environment():
        pid=profile();t=Transport()
        with patch.object(daemon,"native_command",side_effect=t):
            daemon.tick(100);control.profile_action("restart",pid);t.reply(pid);daemon.tick(102)
            t.uncertain=True;daemon.tick(104)
            restart_pending=t.pending(pid).copy()
            assert restart_pending["phase"] == "dispatching"
            assert store.read_snapshot()[1]["profiles"][pid]["request"] == "continuation"
            t.uncertain=False;t.reply(pid,"HADALIS_LOOP:WAIT_RESULT JOB-uncertain")
            daemon.tick(200)
            assert t.count("submit") == 2
            assert store.read_snapshot()[1]["profiles"][pid]["job_id"] == "JOB-uncertain"

    for last_restart, consumed in ((80,True),(101,False)):
        with environment():
            pid=profile();t=Transport()
            with patch.object(daemon,"native_command",side_effect=t):
                daemon.tick(100)
                def legacy(c,s):
                    item=s["profiles"][pid];item["request"]="restart"
                    item["pending"].pop("operation");item["pending"].pop("command_seq")
                    s["events"].append({"kind":"restart","profile_id":pid,"at_unix":last_restart})
                store.change_state(legacy)
                daemon.tick(101)
                assert (store.read_snapshot()[1]["profiles"][pid]["request"]=="continuation") == consumed
                assert t.count("submit") == 1
    print("PASS: one-shot Restart, deferred cancellation receipts/evidence, late WAIT_RESULT, lost ACK and evidence-gated legacy recovery")


if __name__=="__main__":
    main()
