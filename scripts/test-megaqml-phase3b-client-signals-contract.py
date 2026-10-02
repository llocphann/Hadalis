#!/usr/bin/env python3
"""Fake-only strict client-signal contract; NEVER execute vendor or bwrap."""
import ast
import contextlib
import io
import json
import os
from pathlib import Path
import runpy
import sys
from unittest.mock import patch

root = Path(__file__).resolve().parents[1]
source = (root / "scripts/megaqml-phase3b-offline-startup-diagnostic.py")
text = source.read_text(encoding="utf-8")
ast.parse(text)
m = runpy.run_path(str(source), run_name="client_signal_inert_test")
m["self_test"]()  # Exercises inner pure signal parser without MEGAcmd.
assert '"--acknowledge-isolated-offline-client-signals"' in text
assert "private_megacmd_lib=True" in text
assert "client_exit_signal(" in m["INNER"]
assert "p.returncode, timeout, output_limited)" in m["INNER"]
assert 'captured["stdout"]' in m["INNER"]
assert '"client_version_line": version_line' in m["INNER"]
assert '"client_exit_code": exit_code' in m["INNER"]
assert '"client_exit_class": exit_class' in m["INNER"]
assert "client_signals = sys.argv[1:] ==" in text

base = {
    "category": "sandbox_server_log_other",
    "server_log_present": True,
    "client_timed_out": False,
    "client_exit_class": "nonzero",
    "client_exit_code": 9,
    "client_version_line": "not_recognized",
}
def encoded(data):
    return json.dumps(data, sort_keys=True).encode("utf-8")
assert m["accept_inner"](encoded(base), require_signals=True) == base
assert m["accept_inner"](encoded({
    "category": base["category"],
    "server_log_present": base["server_log_present"],
    "client_timed_out": base["client_timed_out"],
}), require_signals=True) is None
invalid = [
    dict(base, client_exit_class="zero"),
    dict(base, client_exit_code=-1),
    dict(base, client_exit_code=True),
    dict(base, client_exit_code=256),
    dict(base, client_exit_class="signal_terminated", client_exit_code=9),
    dict(base, client_exit_class="timed_out", client_exit_code=None),
    dict(base, client_version_line="PRIVATE_LOG"),
    dict(base, category="PRIVATE_LOG"),
    dict(base, raw="PRIVATE_LOG"),
]
for case in invalid:
    assert m["accept_inner"](encoded(case), require_signals=True) is None
safe = m["safe_signal_summary"](
    base["category"], True, False, "nonzero", 9, "not_recognized")
parsed = json.loads(safe)
assert set(parsed) == {
    "phase", "state", "reason", "sandbox_log_present",
    "sandbox_client_timed_out", "network_available", "account_used",
    "server_version_qualified", "live_capabilities_unlocked",
    "client_exit_class", "client_exit_code", "client_version_line",
}
assert parsed["state"] == "UNQUALIFIED"
assert parsed["client_exit_code"] == 9
assert parsed["live_capabilities_unlocked"] is False
assert "PRIVATE_LOG" not in safe

fake = {n: (Path("/usr/bin/" + n), Path("/usr/bin/" + n))
        for n in ("mega-version", "mega-cmd-server", "python3", "bwrap", "true")}
calls = []
def sandbox(_, payload, __, **kwargs):
    calls.append((list(payload), dict(kwargs)))
    return ["FAKE_SANDBOX_ONLY"]
results = iter([
    (0, b"", b"", None), (0, encoded(base), b"PRIVATE_FAKE_STDERR", None)
])
def bounded(argv):
    assert argv == ["FAKE_SANDBOX_ONLY"]
    return next(results)
with patch.object(os, "geteuid", return_value=1000), \
        patch.dict(m["main"].__globals__["BOUNDARY"], {
            "allowed_binary": fake.get, "bwrap_command": sandbox,
            "bounded_process": bounded,
        }), \
        patch.dict(m["main"].__globals__["PRIVATE"], {
            "verify_private_lib_mount": lambda pair: True,
        }), \
        patch.object(sys, "argv", [
            str(source), "--acknowledge-isolated-offline-client-signals",
        ]):
    output = io.StringIO()
    with contextlib.redirect_stdout(output):
        assert m["main"]() == 21
    result = json.loads(output.getvalue())
    assert result["client_exit_code"] == 9
    assert result["client_version_line"] == "not_recognized"
    assert result["state"] == "UNQUALIFIED"
    assert "PRIVATE_FAKE_STDERR" not in output.getvalue()
assert len(calls) == 2
assert all(kw.get("private_megacmd_lib") is True for _, kw in calls)
assert calls[0][0] == [Path("/usr/bin/true")]

never = []
def fail_bounded(_):
    never.append(True)
    raise AssertionError("NO_VENDOR_WHEN_MOUNT_INVALID")
with patch.object(os, "geteuid", return_value=1000), \
        patch.dict(m["main"].__globals__["BOUNDARY"], {
            "allowed_binary": fake.get, "bwrap_command": sandbox,
            "bounded_process": fail_bounded,
        }), \
        patch.dict(m["main"].__globals__["PRIVATE"], {
            "verify_private_lib_mount": lambda pair: False,
        }), \
        patch.object(sys, "argv", [
            str(source), "--acknowledge-isolated-offline-client-signals",
        ]):
    output = io.StringIO()
    with contextlib.redirect_stdout(output):
        assert m["main"]() == 20
    rejected = json.loads(output.getvalue())
    assert rejected["reason"] == "private_lib_mount_validation_failed"
    assert rejected["client_exit_code"] is None
    assert rejected["client_exit_class"] == "unobserved"
    assert rejected["client_version_line"] == "indeterminate"
assert never == []
print("PASS MegaQML Phase3b bounded client-signal fake-only contract")
