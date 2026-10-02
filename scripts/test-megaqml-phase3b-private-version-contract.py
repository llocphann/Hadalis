#!/usr/bin/env python3
"""Fake-only pinned offline numeric-version opt-in; no MEGA or bwrap execution."""
import ast
import contextlib
import io
import json
from pathlib import Path
import runpy
import sys
from unittest.mock import patch

root = Path(__file__).resolve().parents[1]
path = root / "scripts/megaqml-manual-disposable-version-probe.py"
source = path.read_text("utf-8")
ast.parse(source)
m = runpy.run_path(str(path), run_name="private_version_fake")
m["self_test"]()
parse = m["distinct_observed_version"]
assert parse("MEGAcmd version: 2.6.0.0: code 2060000\nMEGA SDK version: 9.1.0\n") == ("2.6.0.0", None)
assert parse("MEGAcmd version: 2.6.0\nMEGAcmd server version: 2.7.0\n") == (
    None, "ambiguous_megacmd_version_lines")
assert parse("Latest version: 99.99.99\n") == (
    None, "vendor_version_format_unrecognized")
assert parse("MEGAcmd version: /private/SECRET\n") == (
    None, "vendor_version_format_unrecognized")
assert parse("MEGAcmd version: " + "9" * 130) == (
    None, "vendor_version_format_unrecognized")
assert '"--acknowledge-disposable-offline-private-libs-version"' in source
assert "private_megacmd_lib=True" in source

fake = {n: (Path("/usr/bin/" + n), Path("/usr/bin/" + n))
        for n in ("mega-version", "mega-cmd-server", "bwrap", "true")}
calls = []
def fake_bounded(argv):
    calls.append(argv)
    return (0, b"", b"", None) if len(calls) == 1 else (
        0, b"MEGAcmd version: 2.6.0.0: code 2060000\n"
           b"MEGA SDK version: 9.0.0\n",
        b"PRIVATE_FAKE_LOG_CANARY", None)
def fake_command(bwrap, payload, parent, **kwargs):
    assert kwargs == {"private_megacmd_lib": True}
    return ["FAKE_SANDBOX", *map(str,payload)]
with patch.object(m["main"].__globals__["os"], "geteuid", return_value=1000), \
        patch.dict(m["main"].__globals__, {"allowed_binary": fake.get,
                                          "bounded_process": fake_bounded,
                                          "bwrap_command": fake_command}), \
        patch("runpy.run_path", return_value={
            "verify_private_lib_mount": lambda pair: True,
        }), \
        patch.object(sys, "argv", [
            str(path), "--acknowledge-disposable-offline-private-libs-version",
        ]):
    stream = io.StringIO()
    with contextlib.redirect_stdout(stream):
        assert m["main"]() == 0
    result = json.loads(stream.getvalue())
    assert result["state"] == "VERSION_OBSERVED_OFFLINE"
    assert result["vendor_version"] == "2.6.0.0"
    assert result["account_used"] is False
    assert result["network_available"] is False
    assert result["live_capabilities_unlocked"] is False
    assert "PRIVATE_FAKE_LOG_CANARY" not in stream.getvalue()
assert len(calls) == 2
calls.clear()
with patch.object(m["main"].__globals__["os"], "geteuid", return_value=1000), \
        patch.dict(m["main"].__globals__, {"allowed_binary": fake.get,
                                          "bounded_process": lambda _: (
                                              (_ for _ in ()).throw(
                                                  AssertionError("vendor must not run"))),
                                          "bwrap_command": fake_command}), \
        patch("runpy.run_path", return_value={
            "verify_private_lib_mount": lambda pair: False,
        }), \
        patch.object(sys, "argv", [
            str(path), "--acknowledge-disposable-offline-private-libs-version",
        ]):
    stream = io.StringIO()
    with contextlib.redirect_stdout(stream):
        assert m["main"]() == 20
    blocked = json.loads(stream.getvalue())
    assert blocked["reason"] == "private_lib_mount_validation_failed"
    assert blocked["vendor_version"] is None
assert calls == []
print("PASS MegaQML private-library offline numeric-version fake-only contract")
