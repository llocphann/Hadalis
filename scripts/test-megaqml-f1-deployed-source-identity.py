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
    def check(expected, expected_code, override=None, deployed_root=None):
        p = run(sys.executable, str(source / m.SCRIPT), "--source-root",
                str(source), "--deployed-config-root",
                str(deployed if deployed_root is None else deployed_root),
                "--expect-sha", pin if override is None else override)
        report = p.stdout.decode()
        assert p.returncode == expected_code, (expected, p.returncode)
        assert "REASON=" + expected + "\n" in report, report
        assert "REAL_DESKTOP_VISUAL_ACCEPTED=NO" in report
        assert "VENDOR_OR_ACCOUNT_USED=NO" in report
        assert str(base) not in report
    check("static_bytes_match", 0)
    # Deterministic fake race: a byte-identical file can change after the
    # first read while a check is underway; never return a stale digest.
    original_open = Path.open
    class MutatingReader:
        def __init__(self, stream, mutate):
            self.stream, self.mutate, self.called = stream, mutate, False
        def __enter__(self):
            self.stream.__enter__()
            return self
        def __exit__(self, *args):
            return self.stream.__exit__(*args)
        def fileno(self):
            return self.stream.fileno()
        def read(self, size=-1):
            data = self.stream.read(size)
            if data and not self.called:
                self.called = True
                self.mutate()
            return data

    target = deployed / m.FILES[0]
    def raced_digest(mutate):
        from unittest.mock import patch
        def injected_open(path, *args, **kwargs):
            stream = original_open(path, *args, **kwargs)
            if path == target and args and args[0] == "rb":
                return MutatingReader(stream, mutate)
            return stream
        with patch.object(Path, "open", injected_open):
            return m.digest(deployed, m.FILES[0])

    assert raced_digest(lambda: target.write_bytes(b"changed during hashing")) is None
    shutil.copyfile(source / m.FILES[0], target)
    replacement = deployed / "replacement"
    replacement.write_bytes(target.read_bytes())
    assert raced_digest(lambda: os.replace(replacement, target)) is None
    shutil.copyfile(source / m.FILES[0], target)
    check("static_bytes_match", 0)
    # A false independent comparison must fail closed, even for byte-identical
    # aliases and hard links; never infer actual running Quickshell identity.
    check("deployment_not_independent", 21, deployed_root=source)
    nested = source / "nested-deployment"
    nested.mkdir()
    check("deployment_not_independent", 21, deployed_root=nested)
    nested.rmdir()
    (deployed / m.FILES[0]).unlink()
    os.link(source / m.FILES[0], deployed / m.FILES[0])
    check("deployment_not_independent", 21)
    (deployed / m.FILES[0]).unlink()
    shutil.copyfile(source / m.FILES[0], deployed / m.FILES[0])
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
