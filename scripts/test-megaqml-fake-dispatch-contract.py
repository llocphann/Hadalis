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
for scenario in ("present", "missing"):
    env = dict(os.environ, MEGAQML_FIXTURE_CASE=scenario)
    request = {"protocol": 1, "request_id": "cloud-detect-1",
               "operation": "detect", "params": {}}
    child = subprocess.run([sys.executable, str(fake), "mega", "request"],
                           input=json.dumps(request) + "\n",
                           capture_output=True, text=True, env=env, timeout=3,
                           check=True)
    result = json.loads(child.stdout)
    assert not child.stderr
    assert result["ok"] is True and result["error"] is None
    assert result["request_id"] == "cloud-detect-1"
    assert [item["name"] for item in result["result"]["binaries"]] == [
        "mega-cmd", "mega-login", "mega-cmd-server", "mega-whoami", "mega-version"]
    expected = scenario == "present"
    assert [item["executable"] for item in result["result"]["binaries"]] == [
        expected, expected, expected, False, expected]
    assert all(item["path"] is None for item in result["result"]["binaries"])
print("PASS MegaQML synthetic runtime dispatcher: 2 cases")
