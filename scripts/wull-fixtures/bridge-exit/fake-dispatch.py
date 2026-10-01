#!/usr/bin/env python3
"""Inert fixture for one companion process at a time, never a vendor helper."""
import json
import os
from pathlib import Path
import sys

if sys.argv[1:] != ["companion"]:
    raise SystemExit(64)

state_path = Path(os.environ["WULL_SMOKE_STATE"])
# The test runner owns this private scratch directory; never touch user state.
count = int(state_path.read_text()) if state_path.exists() else 0
count += 1
state_path.write_text(str(count))

seq = 0


def emit(visibility):
    global seq
    seq += 1
    print(json.dumps({
        "v": 1, "seq": seq, "type": "state",
        "visibility": visibility, "mood": "calm", "activity": "idle",
        "energy": 0.4, "gaze": [0, 0],
        "body": {"squash": 0, "stretch": 0, "lean": 0, "tip": 0, "ripple": 0},
        "face": {"eye": 1, "mouth": 0.1}, "pulse": 0,
    }, separators=(",", ":")), flush=True)


emit("hidden")
if os.environ.get("WULL_SMOKE_CASE") in ("crash-budget", "budget-reset"):
    # Every launch exits immediately to exercise the finite retry budget.
    raise SystemExit(71)

for line in sys.stdin:
    try:
        record = json.loads(line)
    except ValueError:
        raise SystemExit(65)
    if record.get("v") != 1 or record.get("type") != "event":
        raise SystemExit(66)
    event = record.get("event")
    if event == "show":
        emit("present")
    elif event == "click" and count == 1:
        # Fail once, intentionally and without restart; QML must fail closed.
        raise SystemExit(70)
    elif event == "hide":
        emit("hidden")
