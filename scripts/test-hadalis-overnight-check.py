#!/usr/bin/env python3
"""Synthetic pre-bed readiness checks. No real settings, services or Desktop."""
from __future__ import annotations

import contextlib
import copy
import importlib.util
import io
from pathlib import Path
from unittest.mock import patch


def loaded():
    path = Path(__file__).with_name("hadalis-overnight-check.py")
    spec = importlib.util.spec_from_file_location("overnight_check", path)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


def fixtures():
    names = ("MegaQML", "Wull Companion")
    config = {"profiles": [
        {"id": f"private-{n}", "name": n, "enabled": True,
         "mode": "continuous", "auto_protocol_recovery": False,
         "stop_on_done": False, "iteration_limit": 0, "prompt_limit": 0,
         "rotate_after_iterations": 10}
        for n in names
    ]}
    state = {"manager_heartbeat_at_unix": 994, "transport_retry_at_unix": 1100,
             "profiles": {
                 p["id"]: {"desired": "run", "status": "transport_rate_limited",
                           "session": {"conversation_id": f"private-chat-{i}"},
                           "pending": None, "next_run_at_unix": 1100,
                           "protocol_repair_attempts": 0, "chat_iterations": 7}
                 for i, p in enumerate(config["profiles"])
             }}
    return config, state


def exercise():
    m = loaded()
    cfg, state = fixtures()
    out = io.StringIO()
    with patch.object(m.store, "read_snapshot", return_value=(cfg, state, [])):
        with patch.object(m, "unit_check", return_value=True):
            with patch.object(m.time, "time", return_value=1000):
                with contextlib.redirect_stdout(out):
                    assert m.run() == 2
    assert "RESULT=NEEDS_ATTENTION" in out.getvalue()
    assert "private-" not in out.getvalue()

    set_calls = []
    def apply(pid, field, val):
        set_calls.append((pid, field, val))
        p = next(p for p in cfg["profiles"] if p["id"] == pid)
        p[field] = val == "true"

    out = io.StringIO()
    with patch.object(m.store, "read_snapshot", return_value=(cfg, state, [])):
        with patch.object(m.control, "set_profile", side_effect=apply):
            with patch.object(m, "unit_check", return_value=True):
                with patch.object(m.time, "time", return_value=1000):
                    with contextlib.redirect_stdout(out):
                        assert m.run(enable=True) == 0
    assert len(set_calls) == 2
    assert all(field == "auto_protocol_recovery" and val == "true"
               for _, field, val in set_calls)
    assert "RESULT=READY_WITH_EXTERNAL_DEPENDENCIES" in out.getvalue()
    assert "MEGAQML_ROTATE_AFTER_ITERATIONS=10" in out.getvalue()
    assert "WULL_ROTATE_AFTER_ITERATIONS=10" in out.getvalue()
    assert "MEGAQML_CHAT_ITERATIONS=7" in out.getvalue()
    assert "WULL_ROTATION_REMAINING=3" in out.getvalue()
    assert "private-chat" not in out.getvalue()
    state["profiles"][cfg["profiles"][1]["id"]]["status"]="recovering_pending"
    state["profiles"][cfg["profiles"][1]["id"]]["pending"]={"poll_after_unix":1100}
    out=io.StringIO()
    with patch.object(m.store, "read_snapshot", return_value=(cfg, state, [])):
        with patch.object(m, "unit_check", return_value=True):
            with patch.object(m.time, "time", return_value=1000):
                with contextlib.redirect_stdout(out):
                    assert m.run() == 0
    assert "WULL_STATUS=recovering_pending" in out.getvalue()
    assert "RESULT=READY_WITH_EXTERNAL_DEPENDENCIES" in out.getvalue()

    assert "private-" not in out.getvalue()

    # A pause/stop or user-owned limit must not be silently overridden.
    for change, value in (("desired", "paused"), ("stop_on_done", True),
                          ("iteration_limit", 1)):
        c, s = fixtures()
        p = c["profiles"][0]
        target = s["profiles"][p["id"]] if change == "desired" else p
        target[change] = value
        with patch.object(m.store, "read_snapshot", return_value=(c, s, [])):
            with patch.object(m.control, "set_profile") as setting:
                with contextlib.redirect_stdout(io.StringIO()):
                    assert m.run(enable=True) == 2
                setting.assert_not_called()
    print("PASS: overnight preflight fail-closed, opt-in scoped and privacy-safe")


if __name__ == "__main__":
    exercise()
