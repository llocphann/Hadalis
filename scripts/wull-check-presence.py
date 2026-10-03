#!/usr/bin/env python3
"""Bounded real-stdio proof of a twenty-second visit and sixty-second period.

Runs one explicitly supplied companion binary for about sixty-four seconds.
No shell config, desktop input, inference or external service is involved.
"""
import argparse
from collections import deque
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import selectors
import subprocess
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", type=Path, required=True)
    parser.add_argument("--receipt", type=Path, required=True)
    args = parser.parse_args()
    binary, receipt = args.binary.resolve(), args.receipt.resolve()
    if not binary.is_file() or not os.access(binary, os.X_OK):
        parser.error("an executable companion binary is required")
    if receipt.exists() or not receipt.parent.is_dir():
        parser.error("receipt must be a new file in an existing directory")
    started = time.monotonic()
    records = []
    process = subprocess.Popen([str(binary)], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    selector = selectors.DefaultSelector()
    selector.register(process.stdout, selectors.EVENT_READ)
    os.set_blocking(process.stdout.fileno(), False)
    pending, buffer = deque(), b""
    outgoing, incoming = 0, 0

    def read(timeout):
        nonlocal buffer, incoming
        deadline = time.monotonic() + timeout
        while not pending:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                return None
            if not selector.select(remaining):
                return None
            chunk = os.read(process.stdout.fileno(), 65536)
            assert chunk, "native daemon exited before completing proof"
            buffer += chunk
            assert len(buffer) < 65536, "unbounded native output"
            while b"\n" in buffer:
                line, buffer = buffer.split(b"\n", 1)
                assert len(line) <= 8192, "oversized native state"
                pending.append(json.loads(line))
        message = pending.popleft()
        assert message["v"] == 1 and message["type"] == "state" and message["seq"] > incoming
        incoming = message["seq"]
        records.append({"elapsed_s": round(time.monotonic() - started, 4), "state": message})
        return message

    def send(kind, **values):
        nonlocal outgoing
        outgoing += 1
        process.stdin.write((json.dumps({"v": 1, "seq": outgoing, "type": kind, **values}) + "\n").encode())
        process.stdin.flush()
        return read(3)

    try:
        assert read(3)["visibility"] == "hidden"
        ack = send("preferences", personality="balanced", appearance_frequency="frequent")
        assert ack["appearance_frequency"] == "frequent" and ack["visibility"] == "hidden"
        shown_at = time.monotonic()
        assert send("event", event="show")["visibility"] == "present"
        while True:
            message = read(max(0.01, shown_at + 24 - time.monotonic()))
            assert message is not None, "scheduled visit did not end"
            if message["visibility"] == "hidden":
                break
        visit_s = time.monotonic() - shown_at
        assert 19 <= visit_s <= 23, "twenty-second visit deadline missed"
        arrival = read(max(0.01, shown_at + 64 - time.monotonic()))
        period_s = time.monotonic() - shown_at
        assert arrival is not None and arrival["visibility"] == "present"
        assert 59 <= period_s <= 63, "sixty-second arrival period missed or hidden state streamed"
        working = send("event", event="task_start")
        assert working["activity"] == "working" and read(0.8) is None
        changed = send("preferences", personality="calm", appearance_frequency="rare")
        assert changed["activity"] == "working" and changed["personality"] == "calm"
        assert read(0.8) is None
        reaction = send("intent", expression="happy", intensity=0.6, ttl_ms=250)
        assert reaction["expression"] == "happy"
        restored = read(2)
        assert restored is not None
        for key in ("visibility", "activity", "mood", "expression", "energy", "body", "face", "gaze", "pulse"):
            assert restored[key] == changed[key], "intent lost waiting-task baseline: " + key
        assert send("event", event="hide")["visibility"] == "hidden"
        assert send("preferences", personality="energetic", appearance_frequency="always")["visibility"] == "hidden"
        assert read(1) is None, "policy-hidden daemon sent an autonomous state"
        process.stdin.close()
        assert process.wait(timeout=3) == 0
        assert not process.stderr.read(), "native daemon reported an error"
    finally:
        selector.close()
        if process.poll() is None:
            process.terminate()
            process.wait(timeout=3)
    receipt.write_text(json.dumps({
        "schema_version": 1, "recorded_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
        "binary_sha256": hashlib.sha256(binary.read_bytes()).hexdigest(),
        "visit_duration_s": round(visit_s, 4), "appearance_period_s": round(period_s, 4),
        "quiet_gap": True, "waiting_task_preserved": True,
        "policy_hide_cancels_visits": True, "state_records": records
    }, indent=2) + "\n")
    print("WULL_REAL_STDIO_PRESENCE_AND_TASK_HOLD_PASS")
    print(receipt)


if __name__ == "__main__":
    main()
