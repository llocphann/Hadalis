#!/usr/bin/env python3
"""Fake-only gate: classification stays inside isolated tmpfs sandbox."""
import ast
import json
import os
from pathlib import Path
import runpy
import sys
from unittest.mock import patch

root = Path(__file__).resolve().parents[1]
probe = root / "scripts/megaqml-phase3b-offline-startup-diagnostic.py"
text = probe.read_text(encoding="utf-8")
ast.parse(text, filename=str(probe))
m = runpy.run_path(str(probe), run_name="inert-diagnostic-test")
m["self_test"]()  # Only a Python inner-parser self-test, no vendor.

for token in (
        'sys.argv[1:] != ["--acknowledge-isolated-offline-startup-diagnostic"]',
        '"--self-test"', '"/home/disposable/.megaCmd/megacmdserver.log"',
        '"sandbox_server_log_absent"', '"sandbox_server_log_library_missing"',
        '"sandbox_server_log_socket_failure"',
        '"sandbox_server_log_permission_failure"',
        '"sandbox_server_log_network_event"', '"sandbox_server_log_other"',
        '"sandbox_supervisor_error"', "read(4096)", "time.monotonic() + 8.5",
        "start_new_session=True", "os.killpg(p.pid, signal.SIGKILL)",
        'sandbox(bwrap[0], [true[0]]',
        'sandbox(bwrap[0], [python[0], "-I", "-S", "-c", INNER,',
        "return 21"):
    assert token in text, token
for forbidden in ('"--share-net"', '"mega-login"', '"mega-whoami"',
                  'print(captured)', 'print(chunks)', 'print(log)'):
    assert forbidden not in text

parse = m["accept_inner"]
assert parse(b'{"category":"sandbox_server_log_absent",'
             b'"client_timed_out":false,"server_log_present":false}') == {
    "category": "sandbox_server_log_absent",
    "client_timed_out": False,
    "server_log_present": False,
}
for invalid in (
        b'PRIVATE_FAKE_CANARY',
        b'{"category":"sandbox_server_log_other","client_timed_out":false,'
        b'"server_log_present":false,"raw":"PRIVATE_FAKE_CANARY"}',
        b'{"category":"PRIVATE_FAKE_CANARY","client_timed_out":false,'
        b'"server_log_present":false}',
        b'{"category":"sandbox_server_log_other","client_timed_out":0,'
        b'"server_log_present":false}',
        b'{"category":"sandbox_server_log_other","client_timed_out":false,'
        b'"server_log_present":false}\nSECRET',
):
    assert parse(invalid) is None
safe = m["safe_summary"]("sandbox_server_log_absent")
assert "PRIVATE_FAKE_CANARY" not in safe
assert json.loads(safe)["server_version_qualified"] is False
assert json.loads(safe)["live_capabilities_unlocked"] is False

# Simulated bwrap and simulated child reports only. Never execute bwrap or MEGA.
fake = {
    name: (Path("/usr/bin/" + name), Path("/usr/bin/" + name))
    for name in ("mega-version", "mega-cmd-server", "python3", "bwrap", "true")
}
commands = []
def fake_sandbox(_, payload, __):
    commands.append(payload)
    return ["FAKE_SANDBOX"] + list(map(str, payload))
results = iter([
    (0, b"", b"", None),
    (0, b'{"category":"sandbox_server_log_socket_failure",'
        b'"client_timed_out":false,"server_log_present":true}',
     b"PRIVATE_FAKE_STDERR_CANARY", None),
])
def fake_bounded(argv):
    assert argv[0] == "FAKE_SANDBOX"
    return next(results)
with patch.object(os, "geteuid", return_value=1000), \
        patch.dict(m["main"].__globals__["BOUNDARY"], {
            "allowed_binary": fake.get,
            "bwrap_command": fake_sandbox,
            "bounded_process": fake_bounded,
        }), \
        patch.object(sys, "argv", [
            str(probe), "--acknowledge-isolated-offline-startup-diagnostic"]):
    # Avoid raw terminal output even for synthetic canaries.
    import contextlib
    import io
    capture = io.StringIO()
    with contextlib.redirect_stdout(capture):
        assert m["main"]() == 21
    output = capture.getvalue()
assert "PRIVATE_FAKE_STDERR_CANARY" not in output
assert json.loads(output)["reason"] == "sandbox_server_log_socket_failure"
assert len(commands) == 2
assert commands[0] == [Path("/usr/bin/true")]
assert commands[1][:5] == [
    Path("/usr/bin/python3"), "-I", "-S", "-c", m["INNER"]]
assert commands[1][-1] == "/usr/bin/mega-version"
print("PASS MegaQML Phase3b isolated server-log diagnostic fake-only gate")
