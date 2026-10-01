#!/usr/bin/env python3
"""Fake static detect JSON only. Never imports or invokes vendor software."""
import json
import os
import sys

if sys.argv[1:] != ["mega", "request"]:
    raise SystemExit(64)
scenario = os.environ.get("MEGAQML_FIXTURE_CASE")
if scenario not in ("present", "missing", "wrong-id", "unsafe-secret", "malformed", "exit-failure", "hang", "coalesce", "stale-reacquire", "retry-exit", "retry-timeout", "shared-race",
                    "preflight-third-wrong-id", "preflight-timeout", "overlap-timeout"):
    raise SystemExit(65)
line = sys.stdin.readline(8193)
if len(line) > 8192:
    raise SystemExit(66)
try:
    request = json.loads(line)
except ValueError:
    raise SystemExit(67)
# Fake protocol only: opt-in static readiness never invokes a vendor.
operation = request.get("operation") if isinstance(request, dict) else None
if not isinstance(request, dict) or request.get("protocol") != 1 or (
        operation not in ("detect", "connect_preflight")) or (
        request.get("params") != {}) or request.get("secret") is not None:
    raise SystemExit(68)
identifier = request.get("request_id")
prefix = "cloud-preflight-" if operation == "connect_preflight" else "cloud-detect-"
if not isinstance(identifier, str) or not identifier.startswith(prefix) or (
        len(identifier) > 64) or not identifier.replace("-", "").isalnum():
    raise SystemExit(69)
if scenario == "retry-exit" and identifier == "cloud-detect-1":
    import time
    time.sleep(0.8)
    print("PRIVATE_FAKE_STDERR_CANARY", file=sys.stderr, flush=True)
    raise SystemExit(23)
if scenario == "retry-timeout" and identifier == "cloud-detect-1":
    import time
    until = time.monotonic() + 9.5
    while time.monotonic() < until:
        time.sleep(0.1)
    raise SystemExit(24)
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
if scenario == "overlap-timeout" and (
        (operation == "detect" and identifier == "cloud-detect-1") or
        (operation == "connect_preflight" and identifier == "cloud-preflight-1")):
    # Both first fake-only requests intentionally hang. The static deadline
    # must invalidate and reap the concurrently running opt-in preflight;
    # subsequent requests exit quickly so isolated recovery can be proven.
    import time
    until = time.monotonic() + 9.5
    while time.monotonic() < until:
        time.sleep(0.1)
    raise SystemExit(24)
if scenario == "shared-race" and identifier in ("cloud-detect-1", "cloud-detect-2"):
    import time
    time.sleep(0.8)  # Delayed installed replies; third detect is missing.
if scenario in ("coalesce", "stale-reacquire") and identifier == "cloud-detect-1":
    import time
    time.sleep(0.8)  # Consumer changes happen before first reply.
present = scenario == "present" or (
    scenario in ("coalesce", "stale-reacquire") and identifier == "cloud-detect-1") or (
    scenario == "shared-race" and identifier in ("cloud-detect-1", "cloud-detect-2"))
if operation == "connect_preflight" and scenario == "preflight-timeout":
    # Bounded disposable fake; no vendor, network, credentials or writes.
    import time
    until = time.monotonic() + 9.5
    while time.monotonic() < until:
        time.sleep(0.1)
    raise SystemExit(24)
if operation == "connect_preflight":
    preflight = {
        "adapter": "inir-mega",
        "probe_kind": "static_connect_preflight",
        "vendor_execution": "blocked_pending_disposable_qualification",
        "connection_attempted": False,
        "connected": False,
        "auth_qualified": False,
        "account_reads_enabled": False,
        "dependencies_ready": present,
        "reason": ("installed_vendor_not_qualified"
                   if present else "dependency_missing")
    }
    print(json.dumps({
        "protocol": 1,
        "request_id": ("cloud-preflight-replayed"
                       if scenario == "wrong-id" or (
                           scenario == "preflight-third-wrong-id"
                           and identifier == "cloud-preflight-3")
                       else identifier),
        "ok": True, "error": None, "result": preflight
    }, separators=(",", ":")), flush=True)
    raise SystemExit(0)
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
