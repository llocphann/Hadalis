#!/usr/bin/env python3
"""No vendor invocation: synthetic gate and simulated diagnostic boundary."""
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
lib_source = (root / "scripts/megaqml-phase3b-private-lib-mount.py").read_text()
diag_source = (root / "scripts/megaqml-phase3b-offline-startup-diagnostic.py").read_text()
probe_source = (root / "scripts/megaqml-manual-disposable-version-probe.py").read_text()
for source in (lib_source, diag_source, probe_source):
    ast.parse(source)
helper = runpy.run_path(str(root / "scripts/megaqml-phase3b-private-lib-mount.py"),
                       run_name="private_lib_fake_only")
helper["self_test"]()
assert "import subprocess" not in lib_source
assert "import socket" not in lib_source
assert "private_megacmd_lib=False" in probe_source
assert "private_lib_mount_validation_failed" in diag_source
assert "--acknowledge-isolated-offline-private-libs-test" in diag_source

probe = runpy.run_path(str(root / "scripts/megaqml-manual-disposable-version-probe.py"),
                       run_name="inert_probe_import")
basic = probe["bwrap_command"]("/usr/bin/bwrap", ["/usr/bin/true"], Path("/usr/bin"))
extra = probe["bwrap_command"]("/usr/bin/bwrap", ["/usr/bin/true"],
                               Path("/usr/bin"), private_megacmd_lib=True)
bind = ["--dir", "/opt", "--dir", "/opt/megacmd",
        "--ro-bind", "/opt/megacmd/lib", "/opt/megacmd/lib"]
def subsequence(haystack, needle):
    return any(haystack[i:i+len(needle)] == needle
               for i in range(len(haystack)-len(needle)+1))
assert not subsequence(basic, bind)
assert subsequence(extra, bind)
assert extra.count("--ro-bind") == basic.count("--ro-bind") + 1
for token in ("--unshare-all", "--unshare-net", "--as-pid-1",
              "--die-with-parent", "--new-session", "--clearenv"):
    assert token in basic and token in extra
assert "--bind" not in extra and "--share-net" not in extra
assert "--ro-bind" in extra and "--bind" not in extra
assert "/home" not in [extra[i + 1] for i, v in enumerate(extra[:-1])
                        if v == "--ro-bind"]

m = runpy.run_path(str(root / "scripts/megaqml-phase3b-offline-startup-diagnostic.py"),
                   run_name="private_lib_diagnostic_fake")
fake = {name: (Path("/usr/bin/" + name), Path("/usr/bin/" + name))
        for name in ("mega-version", "mega-cmd-server", "python3", "bwrap", "true")}
commands = []
def fake_sandbox(bwrap, payload, vendor_parent, **kwargs):
    commands.append((list(payload), kwargs))
    return ["SIMULATED_ONLY"]
outcome = iter([(0, b"", b"", None),
                (0, b'{"category":"sandbox_server_log_other",'
                    b'"server_log_present":true,"client_timed_out":false}',
                 b"NEVER_PRINT_PRIVATE", None)])
def fake_process(argv):
    assert argv == ["SIMULATED_ONLY"]
    return next(outcome)
def fake_check(pair):
    assert [p[0].name for p in pair] == ["mega-version", "mega-cmd-server"]
    return True
with patch.object(os, "geteuid", return_value=1000), \
        patch.dict(m["main"].__globals__["BOUNDARY"],
                   {"allowed_binary": fake.get,
                    "bwrap_command": fake_sandbox,
                    "bounded_process": fake_process}), \
        patch.dict(m["main"].__globals__["PRIVATE"],
                   {"verify_private_lib_mount": fake_check}), \
        patch.object(sys, "argv", ["private_test",
                     "--acknowledge-isolated-offline-private-libs-test"]):
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        assert m["main"]() == 21
    result = json.loads(buf.getvalue())
    assert result["state"] == "UNQUALIFIED"
    assert result["live_capabilities_unlocked"] is False
    assert "NEVER_PRINT_PRIVATE" not in buf.getvalue()
assert len(commands) == 2
assert all(k.get("private_megacmd_lib") is True for p,k in commands)
assert commands[0][0] == [Path("/usr/bin/true")]

calls = []
def fail_bounded(argv):
    calls.append(argv)
    raise AssertionError("vendor or sandbox should not start")
with patch.object(os, "geteuid", return_value=1000), \
        patch.dict(m["main"].__globals__["BOUNDARY"],
                   {"allowed_binary": fake.get,
                    "bwrap_command": fake_sandbox,
                    "bounded_process": fail_bounded}), \
        patch.dict(m["main"].__globals__["PRIVATE"],
                   {"verify_private_lib_mount": lambda pair: False}), \
        patch.object(sys, "argv", ["private_test",
                     "--acknowledge-isolated-offline-private-libs-test"]):
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        assert m["main"]() == 20
    assert json.loads(buf.getvalue())["reason"] == "private_lib_mount_validation_failed"
assert calls == []
print("PASS MegaQML Phase3b private-lib sandbox fake-only contract")
