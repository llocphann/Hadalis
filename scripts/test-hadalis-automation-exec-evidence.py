#!/usr/bin/env python3
"""Compiler/runtime failures reach the reasoning agent without raw logs."""
import json
from pathlib import Path
import sys

sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from automation.worker.privacy import chat_result, public_result
from automation.worker.diagnostics import validate


def main():
    samples = [
        ("Library import requires a version", "qml_import_version"),
        ("error[E0308]: mismatched types; could not compile", "compile_error"),
        ("test result: FAILED", "test_failure"),
        ("command not found", "command_unavailable"),
        ("cannot update the lock file /private/native/Cargo.lock because --locked was passed", "lockfile_outdated"),
    ]
    for text, code in samples:
        payload={"job":"JOB-debug", "profile_id":"profile-a", "status":"failed", "actions":[{
            "kind":"exec", "exit_code":101, "evidence_id":"JOB-debug:0", "source_sha":"b"*40,
            "observed_at_unix":102, "stdout":"/private/user/home", "stderr":text+"\nPASSWORD=PRIVATE_CANARY ghp_PRIVATE_FAKE_TOKEN_CANARY_12345"}]}
        projected=chat_result(payload)
        assert projected["actions"][0]["observations"][0]["error_codes"] == [code]
        assert projected["actions"][0]["evidence_id"] == "JOB-debug:0"
        assert projected["actions"][0]["source_sha"] == "b"*40
        for view in (projected,public_result(payload)):
            rendered=json.dumps(view)
            assert "PRIVATE_CANARY" not in rendered and "/private" not in rendered
            assert text not in rendered and "stderr" not in rendered and "stdout" not in rendered
        assert "observations" not in public_result(payload)["actions"][0]
        payload["actions"][0]["exit_code"]=0
        assert "observations" not in chat_result(payload)["actions"][0]
    validate({"checks":["services","journal"],"units":["inir.service"],"lines":10})
    try:validate({"checks":["journal"],"units":["private-unrelated.service"]})
    except ValueError:pass
    else:raise AssertionError("unrelated service must remain outside diagnostic scope")
    print("PASS: bounded private compiler/runtime evidence codes with source provenance, no raw log disclosure and actual shell-service diagnostics")


if __name__=="__main__":main()
