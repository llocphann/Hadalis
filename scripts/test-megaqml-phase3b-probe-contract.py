#!/usr/bin/env python3
"""Static + fake-only owner probe safety contract; never executes MEGAcmd."""
import ast
import contextlib
import io
from pathlib import Path
import runpy
import sys
from unittest import mock

root = Path(__file__).resolve().parents[1]
path = root / "scripts/megaqml-manual-disposable-version-probe.py"
source = path.read_text(encoding="utf-8")
ast.parse(source, filename=path.name)
module = runpy.run_path(str(path), run_name="megaqml_probe_test")
assert source.count('"--unshare-all"') >= 1
assert source.count('"--unshare-net"') >= 1
for required in ('"--as-pid-1"', '"--die-with-parent"', '"--clearenv"',
                 '"--tmpfs"', '"--new-session"', '"--perms"', '"0700"',
                 '"--setenv", "HOME", "/home/disposable"',
                 'stdin=subprocess.DEVNULL', 'close_fds=True',
                 'start_new_session=True', 'os.killpg',
                 '"--acknowledge-disposable-offline-probe"'):
    assert required in source, required
assert '--share-net' not in source.split("def bwrap_command", 1)[1].split(
    "def bounded_process", 1)[0]
assert '"--ro-bind", "/", "/"' not in source
assert '"--bind", "/home"' not in source
assert '"--bind", "/run"' not in source
assert '"--bind", "/tmp"' not in source
assert '"mega-login"' not in source
assert '"mega-whoami"' not in source

# A fake vendor marker would be touched if process creation were invoked.
with mock.patch.object(module["subprocess"], "Popen",
                       side_effect=AssertionError("vendor process forbidden")):
    captured = io.StringIO()
    with contextlib.redirect_stdout(captured):
        module["self_test"]()
    assert "PASS MegaQML" in captured.getvalue()
    # Reject any unrecognized CLI value without echoing private input.
    fake = "PRIVATE_FAKE_ACCOUNT_CANARY"
    with mock.patch.object(sys, "argv", [str(path), "--account", fake]):
        captured = io.StringIO()
        with contextlib.redirect_stdout(captured):
            rc = module["main"]()
    assert rc == 20
    assert fake not in captured.getvalue()
    assert '"state": "BLOCKED"' in captured.getvalue()

# Recognize only a bounded, local MEGAcmd version line; not online/SDK state.
parse = module["sanitized_version"]
assert parse("MEGAcmd version: 2.6.0\n") == "2.6.0"
assert parse("MEGAcmd server version: v2.6.1\n") == "2.6.1"
for payload in ("MEGA SDK version: 7.4.3",
                "Latest version available: 100.100.100",
                "MEGAcmd version: /private/path",
                "MEGAcmd version: " + "9" * 130,
                "PRIVATE_FAKE_SECRET_CANARY"):
    assert parse(payload) is None
# No credential, path or raw output is copied into the allowlisted summary.
with contextlib.redirect_stdout(io.StringIO()) as stream:
    module["safe_summary"]("BLOCKED", reason="sandbox_setup_unavailable")
out = stream.getvalue()
for forbidden in ("PRIVATE_FAKE_SECRET_CANARY", "/home/", ".megaCmd",
                  "vendor_stdout", "raw_error"):
    assert forbidden not in out
assert '"live_capabilities_unlocked": false' in out
# Publication is opt-in and may include ONLY the validated, non-account
# JSON summary. Do not run real probes from a fake-only contract.
publisher = (root / "scripts/megaqml-phase3b-owner-local.sh").read_text(
    encoding="utf-8")
for needle in (
        "set -euo pipefail",
        '"$(git branch --show-current)" == dev',
        'git status --porcelain --untracked-files=all',
        "test-megaqml-phase2p-history-guard.py",
        "test-megaqml-phase3b-probe-contract.py",
        "--acknowledge-disposable-offline-probe",
        "network_available", "account_used", "live_capabilities_unlocked",
        "vendor_version", "json.dumps(v, sort_keys=True",
        'git diff --cached --name-only',
        "git push --quiet origin HEAD:refs/heads/dev",
        "phase3b-$short_sha-",
        "PUSHED_SAFE_SUMMARY"):
    assert needle in publisher, needle
assert "git push --force" not in publisher
assert "git reset" not in publisher
assert "git stash" not in publisher
assert "mega-version -l" not in publisher  # Only Python launches inside bwrap.
assert "git merge --ff-only" in publisher
assert "git merge --no-ff" in publisher

print("PASS MegaQML Phase 3b fake-only probe contract: no vendor executed")
