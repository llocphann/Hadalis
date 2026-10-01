#!/usr/bin/env python3
"""Fake static detect JSON only. Never imports or invokes vendor software."""
import json
import os
import sys

if sys.argv[1:] != ["mega", "request"]:
    raise SystemExit(64)
scenario = os.environ.get("MEGAQML_FIXTURE_CASE")
if scenario not in ("present", "missing", "wrong-id", "unsafe-secret", "malformed", "exit-failure", "hang"):
    raise SystemExit(65)
line = sys.stdin.readline(8193)
if len(line) > 8192:
    raise SystemExit(66)
try:
    request = json.loads(line)
except ValueError:
    raise SystemExit(67)
if not isinstance(request, dict) or request.get("protocol") != 1 or (
        request.get("operation") != "detect") or request.get("params") != {}:
    raise SystemExit(68)
identifier = request.get("request_id")
if not isinstance(identifier, str) or not identifier.startswith("cloud-detect-") or (
        len(identifier) > 64) or not identifier.replace("-", "").isalnum():
    raise SystemExit(69)
if scenario == "exit-failure":
    print("PRIVATE_FAKE_STDERR_CANARY", file=sys.stderr, flush=True)
    raise SystemExit(23)
if scenario == "hang":
    # Bounded fake hang: no background job, vendor process or network I/O.
    import time
    until = time.monotonic() + 9.5
    while time.monotonic() < until:
        time.sleep(0.1)
    raise SystemExit(24)
present = scenario == "present"
names = ("mega-cmd", "mega-login", "mega-cmd-server", "mega-whoami", "mega-version")
available = (present, present, present, False, present)
result = {
    "adapter": "inir-mega",
    "probe_kind": "static_no_vendor_execution",
    "vendor_execution": "auth_blocked_pending_disposable_qualification",
    "auth_transport": "private_pty_fake_qualified",
    "secret_argv": False,
    "python_mutation_fallback": False,
    "interactive_shell_available": present,
    "server_available": present,
    "binaries": [{"name": n, "executable": v, "path": None}
                 for n, v in zip(names, available)],
}
if scenario == "unsafe-secret":
    result["secret_argv"] = True
payload = {"protocol": 1,
           "request_id": "cloud-detect-replayed" if scenario == "wrong-id" else identifier,
           "ok": True, "error": None, "result": result}
if scenario == "malformed":
    print('{ "payload": "PRIVATE_FIXTURE_SENTINEL",', flush=True)
else:
    print(json.dumps(payload, separators=(",", ":")), flush=True)
