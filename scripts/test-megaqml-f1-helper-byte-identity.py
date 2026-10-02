#!/usr/bin/env python3
"""Fake files only: no installed helper, MEGAcmd, cargo, or owner state."""
import contextlib
import importlib.util
import io
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

helper = Path(__file__).with_name("megaqml-f1-helper-byte-identity.py")
spec = importlib.util.spec_from_file_location("helper_bytes", helper)
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)


def run(*args, cwd=None):
    return subprocess.run(args, cwd=cwd, capture_output=True, check=False,
                          timeout=10)


with tempfile.TemporaryDirectory() as d:
    base = Path(d)
    src = base / "source"
    src.mkdir()
    trusted = base / "trusted-build"
    trusted.mkdir()
    installed_dir = base / "installed"
    installed_dir.mkdir()
    ref = trusted / "release" / "inir-mega"
    ref.parent.mkdir()
    binary = installed_dir / "inir-mega"
    fake_elf = b"\x7fELFfake-helper-only" + b"\x00" * 16
    ref.write_bytes(fake_elf)
    binary.write_bytes(fake_elf)
    ref.chmod(0o755)
    binary.chmod(0o755)
    check = lambda want: (
        m.compare(src, trusted, ref, binary) == want or
        (_ for _ in ()).throw(AssertionError((want,
                                             m.compare(src, trusted, ref, binary)))))
    check("binary_bytes_match_only")
    binary.write_bytes(fake_elf + b"new data")
    check("binary_bytes_differ")
    binary.write_bytes(fake_elf)
    binary.chmod(0o644)
    check("installed_unqualified")
    binary.chmod(0o755)
    binary.unlink()
    os.link(ref, binary)
    check("binary_inode_alias")
    binary.unlink()
    shutil.copyfile(ref, binary)
    binary.chmod(0o755)
    assert m.compare(src, trusted, ref, trusted / "release" / "inir-mega") == (
        "roots_or_binary_not_independent")
    assert m.compare(src, src, ref, binary) == "roots_or_binary_not_independent"
    # A symlink to an unreviewed target outside the chosen build root fails.
    ref.unlink()
    outside = base / "unreviewed"
    outside.write_bytes(fake_elf)
    outside.chmod(0o755)
    ref.symlink_to(outside)
    check("roots_or_binary_not_independent")
    ref.unlink()
    ref.write_bytes(fake_elf)
    ref.chmod(0o755)
    ref.write_bytes(b"FAKE_NOT_ELF")
    check("reference_unqualified")
    ref.write_bytes(fake_elf)
    m.MAX_HELPER_BYTES = 8
    check("reference_unqualified")
    m.MAX_HELPER_BYTES = 128 * 1024 * 1024
    assert m.source_gate(src, "not a commit", executing_path=helper) == "invalid_pin"

    (src / m.SCRIPT).parent.mkdir(parents=True)
    shutil.copyfile(helper, src / m.SCRIPT)
    (src / "native/inir-mega").mkdir(parents=True)
    (src / "native/Cargo.toml").write_text("[workspace]\n")
    (src / "native/Cargo.lock").write_text("fake lock\n")
    (src / "native/inir-mega/Cargo.toml").write_text("[package]\n")
    assert run("git", "init", "-q", "-b", "dev", str(src)).returncode == 0
    assert run("git", "add", ".", cwd=src).returncode == 0
    assert run("git", "-c", "user.name=Fake", "-c",
               "user.email=fake@example.invalid", "commit", "-qm", "fixture",
               cwd=src).returncode == 0
    pin = run("git", "rev-parse", "HEAD", cwd=src).stdout.decode().strip()
    run_script = src / m.SCRIPT
    assert m.source_gate(src, pin, executing_path=run_script) == (
        "source_pin_and_selected_files_clean")
    assert m.source_gate(src, "f" * 40, executing_path=run_script) == (
        "source_head_mismatch")
    assert m.source_gate(src, pin, executing_path=helper) == (
        "script_source_mismatch")
    (src / "native/inir-mega/Cargo.toml").write_text("dirty")
    assert m.source_gate(src, pin, executing_path=run_script) == (
        "source_files_dirty")

    with contextlib.redirect_stdout(io.StringIO()) as output:
        m.emit("binary_bytes_match_only")
    report = output.getvalue()
    assert "INDEPENDENT_BYTES_MATCH=YES" in report
    assert "TRUSTED_REFERENCE_BUILD_PROVEN=NO" in report
    assert "ACTUAL_DISPATCHER_SELECTION_PROVEN=NO" in report
    assert "RUNNING_HELPER_PROVEN=NO" in report
    assert "VENDOR_OR_ACCOUNT_USED=NO" in report
    assert str(base) not in report

print("PASS F1 fake-only installed-helper byte-comparison contract")
