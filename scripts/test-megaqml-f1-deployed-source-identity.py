#!/usr/bin/env python3
"""No-MEGA regression for the F1 owner-local deployed byte-identity check."""
from pathlib import Path
import os
import shutil
import subprocess
import sys
import tempfile

here = Path(__file__).resolve().parent
helper = here / "megaqml-f1-deployed-source-identity.py"
sys.path.insert(0, str(here))
import importlib.util
spec = importlib.util.spec_from_file_location("f1identity", helper)
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)


def run(*argv, cwd=None):
    p = subprocess.run(argv, cwd=cwd, capture_output=True, check=False,
                       timeout=12, env={**os.environ, "GIT_CONFIG_NOSYSTEM": "1"})
    return p


with tempfile.TemporaryDirectory() as d:
    base = Path(d)
    source, deployed = base / "source", base / "deployed"
    source.mkdir()
    deployed.mkdir()
    for rel in (*m.FILES, m.SCRIPT):
        original = source / rel
        original.parent.mkdir(parents=True, exist_ok=True)
        if rel == m.SCRIPT:
            original.write_bytes(helper.read_bytes())
        else:
            original.write_bytes(("fake-only fixture: " + rel).encode("ascii"))
        if rel in m.FILES:
            target = deployed / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(original, target)
    assert run("git", "init", "-q", "-b", "dev", str(source)).returncode == 0
    assert run("git", "add", ".", cwd=source).returncode == 0
    assert run("git", "-c", "user.name=Fixture", "-c",
               "user.email=fixture@example.invalid", "commit",
               "-qm", "fixture", cwd=source).returncode == 0
    pin = run("git", "rev-parse", "HEAD", cwd=source).stdout.decode().strip()
    def check(expected, expected_code, override=None):
        p = run(sys.executable, str(source / m.SCRIPT), "--source-root",
                str(source), "--deployed-config-root", str(deployed),
                "--expect-sha", pin if override is None else override)
        report = p.stdout.decode()
        assert p.returncode == expected_code, (expected, p.returncode)
        assert "REASON=" + expected + "\n" in report, report
        assert "REAL_DESKTOP_VISUAL_ACCEPTED=NO" in report
        assert "VENDOR_OR_ACCOUNT_USED=NO" in report
        assert str(base) not in report
    check("static_bytes_match", 0)
    check("source_head_mismatch", 21, "0" * 40)
    (deployed / m.FILES[0]).write_bytes(b"mismatched")
    check("deployed_mismatch", 21)
    shutil.copyfile(source / m.FILES[0], deployed / m.FILES[0])
    (source / m.FILES[1]).write_bytes(b"locally dirty")
    check("source_files_dirty", 21)
    (source / m.FILES[1]).write_bytes(
        ("fake-only fixture: " + m.FILES[1]).encode("ascii"))
    (deployed / m.FILES[2]).unlink()
    check("file_unavailable", 21)
    outside = base / "outside"
    outside.write_bytes(b"secret outside the declared tree")
    (deployed / m.FILES[2]).symlink_to(outside)
    check("file_unavailable", 21)
print("PASS F1 deployed source byte-identity fake-only contract")
