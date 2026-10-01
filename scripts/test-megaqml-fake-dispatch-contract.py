#!/usr/bin/env python3
"""Pure fixture contract. Fake dispatcher only; no MEGAcmd execution."""
import json
import os
from pathlib import Path
import subprocess
import sys

fake = Path(__file__).resolve().parent / "megaqml-fixtures/fake-static-dispatch.py"
source = fake.read_text(encoding="utf-8")
assert "subprocess" not in source and "os.system" not in source
assert '"mega", "request"' in source
for scenario in ("present", "missing", "wrong-id", "unsafe-secret", "malformed", "exit-failure", "hang", "coalesce", "stale-reacquire", "retry-exit", "retry-timeout", "shared-race"):
    env = dict(os.environ, MEGAQML_FIXTURE_CASE=scenario)
    request = {"protocol": 1, "request_id": "cloud-detect-1",
               "operation": "detect", "params": {}}
    if scenario == "hang" or scenario == "retry-timeout":
        try:
            subprocess.run([sys.executable, str(fake), "mega", "request"],
                           input=json.dumps(request) + "\n",
                           capture_output=True, text=True, env=env, timeout=0.6)
        except subprocess.TimeoutExpired:
            pass
        else:
            raise AssertionError("fake hang must block until killed")
        continue
    child = subprocess.run([sys.executable, str(fake), "mega", "request"],
                           input=json.dumps(request) + "\n",
                           capture_output=True, text=True, env=env, timeout=3)
    if scenario == "exit-failure" or scenario == "retry-exit":
        assert child.returncode == 23
        assert child.stdout == ""
        assert child.stderr.strip() == "PRIVATE_FAKE_STDERR_CANARY"
        continue
    assert child.returncode == 0
    assert not child.stderr
    if scenario == "malformed":
        assert "PRIVATE_FIXTURE_SENTINEL" in child.stdout
        try:
            json.loads(child.stdout)
        except json.JSONDecodeError:
            pass
        else:
            raise AssertionError("malformed fixture must be invalid JSON")
        continue
    result = json.loads(child.stdout)
    assert result["ok"] is True and result["error"] is None
    assert result["request_id"] == ("cloud-detect-replayed" if scenario == "wrong-id" else "cloud-detect-1")
    assert result["result"]["secret_argv"] is (scenario == "unsafe-secret")
    assert [item["name"] for item in result["result"]["binaries"]] == [
        "mega-cmd", "mega-login", "mega-cmd-server", "mega-whoami", "mega-version"]
    expected = scenario == "present" or (scenario in ("coalesce", "stale-reacquire", "shared-race"))
    assert [item["executable"] for item in result["result"]["binaries"]] == [
        expected, expected, expected, False, expected]
    assert all(item["path"] is None for item in result["result"]["binaries"])
# Second request differs from first; client must not replay stale inventory.
for scenario in ("coalesce", "stale-reacquire", "retry-exit", "retry-timeout"):
    env = dict(os.environ, MEGAQML_FIXTURE_CASE=scenario)
    request = {"protocol": 1, "request_id": "cloud-detect-2",
               "operation": "detect", "params": {}}
    child = subprocess.run([sys.executable, str(fake), "mega", "request"],
                           input=json.dumps(request) + "\n", capture_output=True,
                           text=True, env=env, timeout=3, check=True)
    result = json.loads(child.stdout)
    assert result["request_id"] == "cloud-detect-2"
    assert not result["result"]["interactive_shell_available"]
    assert not result["result"]["server_available"]
    assert all(not x["executable"] for x in result["result"]["binaries"])
    assert not child.stderr
# Check two extra race replies without exposing fake paths.
env = dict(os.environ, MEGAQML_FIXTURE_CASE="shared-race")
for serial, present in ((2, True), (3, False)):
    req = {"protocol": 1, "request_id": f"cloud-detect-{serial}",
           "operation": "detect", "params": {}}
    child = subprocess.run([sys.executable, str(fake), "mega", "request"],
                           input=json.dumps(req) + "\n", capture_output=True,
                           text=True, env=env, timeout=3, check=True)
    result = json.loads(child.stdout)
    assert child.stderr == "" and result["request_id"] == f"cloud-detect-{serial}"
    assert result["result"]["interactive_shell_available"] is present
    assert result["result"]["server_available"] is present
    assert [b["executable"] for b in result["result"]["binaries"]] == [
        present, present, present, False, present]
print("PASS MegaQML synthetic runtime dispatcher: 12 cases plus four second requests and two race requests")
# F1 offline preflight uses exactly the same fake-only transport with a
# distinct request ID prefix. These fixtures can never execute MEGAcmd.
for scenario, ready in (("present", True), ("missing", False)):
    env = dict(os.environ, MEGAQML_FIXTURE_CASE=scenario)
    request = {"protocol": 1, "request_id": "cloud-preflight-1",
               "operation": "connect_preflight", "params": {}}
    child = subprocess.run([sys.executable, str(fake), "mega", "request"],
                           input=json.dumps(request) + "\n", capture_output=True,
                           text=True, env=env, timeout=3, check=True)
    response = json.loads(child.stdout)
    assert child.stderr == "" and response["request_id"] == "cloud-preflight-1"
    assert response["ok"] is True and response["error"] is None
    result = response["result"]
    assert result["probe_kind"] == "static_connect_preflight"
    assert result["vendor_execution"] == "blocked_pending_disposable_qualification"
    assert result["dependencies_ready"] is ready
    assert result["reason"] == (
        "installed_vendor_not_qualified" if ready else "dependency_missing")
    for field in ("connected", "connection_attempted", "auth_qualified",
                  "account_reads_enabled"):
        assert result[field] is False
    assert "path" not in child.stdout.lower()
# Malformed preflight may not smuggle secrets or arbitrary raw commands.
for forbidden in ({"secret": {"password": "PRIVATE_FAKE_SECRET_CANARY"}},
                  {"params": {"command": "mega-rm"}}):
    request = {"protocol": 1, "request_id": "cloud-preflight-2",
               "operation": "connect_preflight", "params": {}, **forbidden}
    env = dict(os.environ, MEGAQML_FIXTURE_CASE="present")
    child = subprocess.run([sys.executable, str(fake), "mega", "request"],
                           input=json.dumps(request) + "\n", capture_output=True,
                           text=True, env=env, timeout=3)
    assert child.returncode == 68 and child.stdout == ""
    assert "PRIVATE_FAKE_SECRET_CANARY" not in child.stderr
print("PASS MegaQML fake dispatcher inert preflight: 2 success and 2 rejection cases")
# Preserve the old fake static detection scenario while exercising a new
# opt-in-only wrong-ID replay: requests one and two must be accepted, third
# must carry a mismatched ID, and all remain offline with no account actions.
env = dict(os.environ, MEGAQML_FIXTURE_CASE="preflight-third-wrong-id")
for serial in (1, 2, 3):
    request = {"protocol": 1, "request_id": f"cloud-preflight-{serial}",
               "operation": "connect_preflight", "params": {}}
    child = subprocess.run(
        [sys.executable, str(fake), "mega", "request"],
        input=json.dumps(request) + "\n", capture_output=True,
        text=True, env=env, timeout=3, check=True)
    result = json.loads(child.stdout)
    assert result["ok"] is True and not child.stderr
    assert result["request_id"] == (
        "cloud-preflight-replayed" if serial == 3 else f"cloud-preflight-{serial}")
    assert result["result"]["connected"] is False
    assert result["result"]["connection_attempted"] is False
    assert result["result"]["account_reads_enabled"] is False
    assert result["result"]["dependencies_ready"] is False
print("PASS MegaQML fake-only F1 preflight: valid twice, wrong-ID third")

