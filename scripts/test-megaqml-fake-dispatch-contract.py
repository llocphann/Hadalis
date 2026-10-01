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
for scenario in ("present", "missing", "wrong-id", "unsafe-secret", "malformed", "exit-failure", "hang"):
    env = dict(os.environ, MEGAQML_FIXTURE_CASE=scenario)
    request = {"protocol": 1, "request_id": "cloud-detect-1",
               "operation": "detect", "params": {}}
    if scenario == "hang":
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
    if scenario == "exit-failure":
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
    expected = scenario == "present"
    assert [item["executable"] for item in result["result"]["binaries"]] == [
        expected, expected, expected, False, expected]
    assert all(item["path"] is None for item in result["result"]["binaries"])
print("PASS MegaQML synthetic runtime dispatcher: 7 cases")
