#!/usr/bin/env python3
"""Missing responses stay observable, durable and isolated without replay."""
import json
from unittest.mock import patch

from automation_test_helpers import environment, profile, Transport, daemon, store


class ObservedTransport(Transport):
    def __init__(self):
        super().__init__()
        self.observation = {}

    def __call__(self, op, **data):
        result = super().__call__(op, **data)
        if op == "poll" and not result.get("completed"):
            result.update(self.observation.get(data["pending"]["user_message_id"], {}))
        return result


def main():
    with environment():
        a, b = profile("Interrupted"), profile("Independent")
        transport = ObservedTransport()
        with patch.object(daemon, "native_command", side_effect=transport):
            daemon.tick(100)
            original = transport.pending(a).copy()
            uid = original["user_message_id"]
            store.change_state(lambda c, s: s["profiles"][a]["pending"].update(resume_attempts=3))
            transport.observation[uid] = {
                "server_stream_status": "COMPLETE", "client_stream_error": True,
                "client_stream_complete": False, "privateBody": "PRIVATE_CANARY"}
            transport.reply(b, "HADALIS_LOOP:DONE")
            daemon.tick(500)
            state = store.read_snapshot()[1]
            item = state["profiles"][a]
            assert item["desired"] == "run" and item["status"] == "response_unavailable"
            assert item["pending"]["user_message_id"] == uid
            assert item["pending"]["conversation_id"] == original["conversation_id"]
            assert item["iterations"] == 0 and item["generation_recoveries"] == 0
            assert item["pending"]["observation"]["server_stream_status"] == "COMPLETE"
            assert item["pending"]["observation"]["client_stream_error"] is True
            assert item["pending"]["poll_after_unix"] >= 530
            assert state["profiles"][b]["status"] == "completed"
            assert state["profiles"][b]["iterations"] == 1
            assert transport.count("submit") == 2 and transport.count("resume") == 0
            assert "PRIVATE_CANARY" not in store.state_path().read_text()

            # Repeated observations and a lost Desktop receipt do not replay
            # the turn, manufacture progress, or fill Activity with duplicates.
            for now in (560, 620):
                daemon.tick(now)
            transport.observation[uid].update(client_stream_error=False)
            daemon.tick(680)
            state = store.read_snapshot()[1]
            assert state["profiles"][a]["status"] == "response_unavailable"
            assert len([e for e in state["events"] if e.get("profile_id") == a and
                        e["kind"] == "response_observation"]) == 1
            durable = json.loads(store.state_path().read_text())["profiles"][a]
            assert durable["pending"]["observation"] == state["profiles"][a]["pending"]["observation"]

            # Network retries retain the last successful observation. An
            # explicit active server stream outranks stale client errors.
            daemon._observe_failure(a, 700, RuntimeError("DESKTOP_RATE_LIMITED"), pending=transport.pending(a))
            assert transport.pending(a)["observation"]["server_stream_status"] == "COMPLETE"
            transport.observation[uid].update(server_stream_status="IS_STREAMING", client_stream_error=True)
            daemon.tick(700 + daemon.RATE_LIMIT_SECONDS)
            assert store.read_snapshot()[1]["profiles"][a]["status"] == "thinking"
            transport.observation[uid].update(server_stream_status="UNAVAILABLE")
            daemon.tick(800 + daemon.RATE_LIMIT_SECONDS)
            assert store.read_snapshot()[1]["profiles"][a]["status"] == "stream_failed"
            assert transport.count("submit") == 2 and transport.count("resume") == 0
            transport.observation[uid].update(client_stream_error=False, client_stream_complete=True)
            daemon.tick(850 + daemon.RATE_LIMIT_SECONDS)
            assert store.read_snapshot()[1]["profiles"][a]["status"] == "response_unavailable"

            # A final response for the original message is still accepted and
            # consumed once; monitoring was never disabled by the warning.
            transport.reply(a, "HADALIS_LOOP:DONE")
            daemon.tick(900 + daemon.RATE_LIMIT_SECONDS)
            daemon.tick(1000 + daemon.RATE_LIMIT_SECONDS)
            item = store.read_snapshot()[1]["profiles"][a]
            assert item["status"] == "completed" and item["iterations"] == 1
            assert item["pending"] is None and item["generation_recoveries"] == 0
            assert transport.count("submit") == 2
    with environment():
        pid = profile("Await job")
        transport = ObservedTransport()
        with patch.object(daemon, "native_command", side_effect=transport):
            daemon.tick(100)
            uid = transport.pending(pid)["user_message_id"]
            store.change_state(lambda c, s: s["profiles"][pid]["pending"].update(resume_attempts=3))
            transport.observation[uid] = {"server_stream_status": "COMPLETE", "client_stream_error": True}
            daemon.tick(500)
            assert store.read_snapshot()[1]["profiles"][pid]["status_detail"]
            transport.reply(pid, "HADALIS_LOOP:WAIT_RESULT JOB-observation")
            daemon.tick(560)
            item = store.read_snapshot()[1]["profiles"][pid]
            assert item["status"] == "waiting_result" and item["job_id"] == "JOB-observation"
            assert item["status_detail"] == "" and item["pending"] is None
            assert item["iterations"] == 1 and transport.count("submit") == 1
    print("PASS: durable closed/interrupted stream evidence, independent profile completion, bounded events, rate-limit/restart observation and no prompt replay")


if __name__ == "__main__":
    main()
