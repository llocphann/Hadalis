#!/usr/bin/env python3
"""Fake filesystem only: installed-package metadata, never a MEGAcmd call."""
import ast
from contextlib import redirect_stdout
from io import StringIO
from pathlib import Path
import json
import runpy
import sys
from tempfile import TemporaryDirectory
from unittest.mock import patch

root = Path(__file__).resolve().parents[1]
path = root / "scripts/megaqml-phase3b-static-package.py"
source = path.read_text("utf-8")
tree = ast.parse(source)
# Fail closed on any process execution: this tool must be a pure local
# read of package-manager metadata and fixed binary identities.
for node in ast.walk(tree):
    if isinstance(node, (ast.Import, ast.ImportFrom)):
        assert all(getattr(item, "name", "") not in (
            "subprocess", "ctypes", "pty", "socket", "urllib", "requests")
            for item in node.names)
for forbidden in ("subprocess.", "os.system", "os.exec", "os.spawn",
                  "Popen(", "shell=True", "mega-version -l", "mega-cmd-server -",
                  ".megaCmd", "MEGACMD_SOCKET_NAME"):
    assert forbidden not in source, forbidden

m = runpy.run_path(str(path), run_name="megaqml_fake_static_module")
fake_pair = [
    (Path("/usr/bin/mega-version"), Path("/usr/bin/mega-version")),
    (Path("/usr/bin/mega-cmd-server"), Path("/usr/bin/mega-cmd-server")),
]
assert m["package_version"]("2.6.0-1") == "2.6.0"
assert m["package_version"]("2.6.0.0-1") == "2.6.0.0"
for unsafe in ("2.6.0\nSECRET", "/home/account", "latest-version",
               "2.6.0;rm -rf /", "9999.9999.9999"):
    assert m["package_version"](unsafe) is None

with TemporaryDirectory(prefix="megaqml-static-fixture-") as temp:
    fixture = Path(temp)
    arch = fixture / "var/lib/pacman/local/megacmd-2.6.0-1"
    arch.mkdir(parents=True)
    (arch / "desc").write_text(
        "%NAME%\nmegacmd\n\n%VERSION%\n2.6.0-1\n")
    (arch / "files").write_text(
        "%FILES%\nusr/bin/mega-version\nusr/bin/mega-cmd-server\n")
    assert m["pacman_metadata"](fake_pair, fixture) == {
        "source": "pacman_local_db", "version": "2.6.0"}
    (arch / "files").write_text("%FILES%\nusr/bin/mega-version\n")
    assert m["pacman_metadata"](fake_pair, fixture) is None
    (arch / "files").write_text(
        "%FILES%\nusr/bin/mega-version\nusr/bin/mega-cmd-server\n")
    (arch / "desc").write_text(
        "%NAME%\nmegacmd\n\n%VERSION%\nPRIVATE_ACCOUNT_CANARY\n")
    assert m["pacman_metadata"](fake_pair, fixture) is None

    deb = fixture / "var/lib/dpkg"
    info = deb / "info"
    info.mkdir(parents=True)
    (deb / "status").write_text(
        "Package: mega-cmd\nStatus: install ok installed\n"
        "Version: 2.6.0-1\n\n")
    (info / "mega-cmd.list").write_text(
        "/usr/bin/mega-version\n/usr/bin/mega-cmd-server\n")
    assert m["dpkg_metadata"](fake_pair, fixture) == {
        "source": "dpkg_local_db", "version": "2.6.0"}
    (info / "mega-cmd.list").write_text("/usr/bin/mega-version\n")
    assert m["dpkg_metadata"](fake_pair, fixture) is None
    (info / "mega-cmd.list").write_text(
        "/usr/bin/mega-version\n/usr/bin/mega-cmd-server\n")
    (deb / "status").write_text(
        "Package: mega-cmd\nStatus: deinstall ok config-files\n"
        "Version: 2.6.0-1\n\n")
    assert m["dpkg_metadata"](fake_pair, fixture) is None

nix_pair = [
    (Path("/nix/store/" + "a" * 32 + "-megacmd-2.6.0/bin/mega-version"),
     Path("/nix/store/" + "a" * 32 + "-megacmd-2.6.0/bin/mega-version")),
    (Path("/nix/store/" + "a" * 32 + "-megacmd-2.6.0/bin/mega-cmd-server"),
     Path("/nix/store/" + "a" * 32 + "-megacmd-2.6.0/bin/mega-cmd-server")),
]
assert m["nix_metadata"](nix_pair) == {
    "source": "nix_derivation_label", "version": "2.6.0"}
assert m["nix_metadata"](fake_pair) is None

with patch.dict(m["inspect"].__globals__, {
    "pacman_metadata": lambda pair: None,
    "dpkg_metadata": lambda pair: None,
    "nix_metadata": lambda pair: None,
}):
    assert m["inspect"](fake_pair)["status"] == "UNVERIFIED"

result = m["summary"]({
    "status": "PACKAGE_VERSION_OBSERVED", "source": "pacman_local_db",
    "version": "2.6.0", "reason": "package_not_running_server"})
assert result["server_version_qualified"] is False
assert result["vendor_executed"] is False
assert result["live_capabilities_unlocked"] is False

output = StringIO()
with patch.dict(m["main"].__globals__, {"candidate_pair": lambda: None}):
    with patch.object(sys, "argv", [str(path),
          "--acknowledge-vendor-free-static-triage"]):
        with redirect_stdout(output):
            assert m["main"]() == 0
published = json.loads(output.getvalue())
assert published["state"] == "UNVERIFIED"
assert published["package_version"] is None
assert published["server_version_qualified"] is False
assert "PRIVATE_ACCOUNT_CANARY" not in output.getvalue()
# Review evidence publisher source without executing git, bubblewrap or vendor.
publisher = (root / "scripts/megaqml-phase3b-static-owner-local.sh").read_text("utf-8")
for token in (
        "--acknowledge-vendor-free-static-triage",
        "test-megaqml-phase3b-static-package.py",
        "megaqml-phase3b-static-package.py",
        "server_version_qualified", "vendor_executed", "package_version",
        "test-megaqml-phase2p-history-guard.py",
        "git diff --cached --name-only",
        "git push --quiet origin HEAD:refs/heads/dev"):
    assert token in publisher, token
for unsafe in ("--force", "git reset", "git stash",
               "mega-version -l", "mega-login", "mega-whoami"):
    assert unsafe not in publisher, unsafe

print("PASS MegaQML Phase 3b vendor-free package metadata fake fixtures")
