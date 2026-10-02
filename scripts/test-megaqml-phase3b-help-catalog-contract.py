#!/usr/bin/env python3
"""Fake-only: strict no-output-leak offline help catalog and unchanged bwrap."""
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
src = root / "scripts/megaqml-phase3b-offline-help-catalog.py"
text = src.read_text()
ast.parse(text)
m = runpy.run_path(str(src), run_name="help_catalog_fake_only")
m["self_test"]()
assert '"--acknowledge-disposable-offline-help-catalog"' in text
assert "private_megacmd_lib=True" in text
assert '"--unshare-net"' not in text  # inherit the existing tested bwrap
assert '["exe", "df"]' not in text  # no account/data command
assert '"help", "-f"' in m["INNER"]
assert '"version", "-l"' in m["INNER"]
assert m["summary"]("explicit_acknowledgment_required").find("PRIVATE") < 0

good = {
    "reason": "help_catalog_observed", "version_line_consistent": True,
    "commands": {"version": True, "df": True, "sync": True, "transfers": True},
}
assert m["accept_inner"](json.dumps(good).encode()) == good
for invalid in [
    dict(good, secret="PRIVATE_CANARY"),
    dict(good, reason="PRIVATE_CANARY"),
    dict(good, version_line_consistent=False),
    dict(good, commands={"version": True}),
    dict(good, commands=dict.fromkeys(good["commands"], False)),
    dict(good, commands={"version": 1, "df": True,
                         "sync": True, "transfers": True}),
]:
    assert m["accept_inner"](json.dumps(invalid).encode()) is None

fake = {n:(Path("/usr/bin/" + n),Path("/usr/bin/" + n))
        for n in ("mega-version","mega-cmd-server","mega-exec","bwrap","python3","true")}
calls=[]
def fake_bwrap(_,payload,__ ,**kwargs):
    assert kwargs == {"private_megacmd_lib":True}
    calls.append(payload)
    return ["SIMULATED_SANDBOX_ONLY"]
results=iter([
    (0,b"",b"",None),
    (0,json.dumps(good).encode(),b"PRIVATE_STDERR_CANARY",None)
])
def fake_bounded(argv):
    assert argv == ["SIMULATED_SANDBOX_ONLY"]
    return next(results)
with patch.object(os,"geteuid",return_value=1000), \
        patch.dict(m["main"].__globals__["BOUNDARY"],{
            "allowed_binary":fake.get,"bwrap_command":fake_bwrap,
            "bounded_process":fake_bounded}), \
        patch.dict(m["main"].__globals__["PRIVATE"],{
            "verify_private_lib_mount":lambda pair:True}), \
        patch.dict(m["main"].__globals__,{
            "package_executor_owned":lambda pair, exe: True}), \
        patch.object(sys,"argv",["help", "--acknowledge-disposable-offline-help-catalog"]):
    out=io.StringIO()
    with contextlib.redirect_stdout(out):
        assert m["main"]()==0
    v=json.loads(out.getvalue())
    assert v["state"]=="CATALOG_OBSERVED_OFFLINE"
    assert v["commands"]==good["commands"]
    assert v["help_parsers_qualified"] is False
    assert v["server_identity_qualified"] is False
    assert v["network_available"] is False
    assert v["live_capabilities_unlocked"] is False
    assert "PRIVATE_STDERR_CANARY" not in out.getvalue()
assert len(calls)==2
assert calls[0] == [Path("/usr/bin/true")]
assert calls[1][:5] == [Path("/usr/bin/python3"), "-I", "-S", "-c",m["INNER"]]

started=[]
with patch.object(os,"geteuid",return_value=1000), \
        patch.dict(m["main"].__globals__["BOUNDARY"],{
            "allowed_binary":fake.get,"bwrap_command":fake_bwrap,
            "bounded_process":lambda argv:started.append(argv)}), \
        patch.dict(m["main"].__globals__["PRIVATE"],{
            "verify_private_lib_mount":lambda pair:False}), \
        patch.object(sys,"argv",["help", "--acknowledge-disposable-offline-help-catalog"]):
    out=io.StringIO()
    with contextlib.redirect_stdout(out):
        assert m["main"]()==20
    assert json.loads(out.getvalue())["reason"]=="private_lib_mount_validation_failed"
assert not started
print("PASS MegaQML isolated help-catalog fake-only contract")
