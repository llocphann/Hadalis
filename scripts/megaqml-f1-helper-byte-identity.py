#!/usr/bin/env python3
"""Owner-local offline inir-mega binary comparison; never execute either binary.

A reference binary is owner-supplied, NOT built or source-attested by this
script. A byte match alone does not prove the installed dispatcher selects it.
"""
import argparse
import hashlib
import os
from pathlib import Path
import re
import stat
import subprocess

SCRIPT = "scripts/megaqml-f1-helper-byte-identity.py"
SOURCE_PATHS = (SCRIPT, "native/Cargo.toml", "native/Cargo.lock", "native/inir-mega")
MAX_HELPER_BYTES = 128 * 1024 * 1024


def git(source, *argv):
    try:
        done = subprocess.run(
            ["git", "-c", "core.fsmonitor=false", "-C", str(source), *argv],
            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, check=False,
            timeout=8, env={**os.environ, "GIT_OPTIONAL_LOCKS": "0"})
        return done.stdout if done.returncode == 0 else None
    except (OSError, subprocess.TimeoutExpired):
        return None


def source_gate(source, expect_sha, executing_path=None):
    if not re.fullmatch(r"[0-9a-f]{40}", expect_sha):
        return "invalid_pin"
    try:
        source = Path(source).resolve(strict=True)
        script = (source / SCRIPT).resolve(strict=True)
        invoked = Path(executing_path or __file__).resolve(strict=True)
        if not source.is_dir() or script != invoked:
            return "script_source_mismatch"
    except (OSError, RuntimeError):
        return "source_unavailable"
    top = git(source, "rev-parse", "--show-toplevel")
    head = git(source, "rev-parse", "--verify", "HEAD")
    if top is None or head is None or os.fsdecode(top.strip()) != str(source):
        return "source_unverified"
    if head.decode("ascii", "ignore").strip() != expect_sha:
        return "source_head_mismatch"
    changes = git(source, "status", "--porcelain", "--untracked-files=all",
                  "--", *SOURCE_PATHS)
    if changes is None or changes.strip():
        return "source_files_dirty"
    return "source_pin_and_selected_files_clean"


def digest_helper(path):
    """Hash stable ELF bytes from the actual opened descriptor, fail closed."""
    try:
        target = path.resolve(strict=True)
        initial = path.stat()
        fingerprint = lambda x: (x.st_dev, x.st_ino, x.st_mode, x.st_size,
                                 x.st_mtime_ns, x.st_ctime_ns)
        if (not stat.S_ISREG(initial.st_mode) or
                not initial.st_mode & (stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH) or
                initial.st_size < 4 or initial.st_size > MAX_HELPER_BYTES):
            return None

        def path_unchanged():
            return (path.resolve(strict=True) == target and
                    fingerprint(path.stat()) == fingerprint(initial))

        if not path_unchanged():
            return None
        h = hashlib.sha256()
        consumed = 0
        with target.open("rb") as stream:
            opened = os.fstat(stream.fileno())
            # A path stat before/after read does not identify the descriptor
            # if the file was replaced during open or an alias was retargeted.
            if fingerprint(opened) != fingerprint(initial):
                return None
            prefix = stream.read(4)
            if prefix != b"\x7fELF":
                return None
            h.update(prefix)
            consumed = 4
            while True:
                data = stream.read(65536)
                if not data:
                    break
                consumed += len(data)
                if consumed > MAX_HELPER_BYTES:
                    return None
                h.update(data)
            # Detect in-place writes while hashing the already-open inode.
            if (consumed != opened.st_size or
                    fingerprint(os.fstat(stream.fileno())) != fingerprint(opened)):
                return None
        if not path_unchanged():
            return None
        return h.digest()
    except (OSError, ValueError, RuntimeError):
        return None


def compare(source, build_root, reference, installed):
    try:
        source = Path(source).resolve(strict=True)
        build_root = Path(build_root).resolve(strict=True)
        reference = Path(reference).resolve(strict=True)
        installed = Path(installed).resolve(strict=True)
        if (not source.is_dir() or not build_root.is_dir()
                or not reference.is_relative_to(build_root)
                or build_root.is_relative_to(source)
                or source.is_relative_to(build_root)
                or installed.is_relative_to(build_root)
                or installed.is_relative_to(source)
                or reference == installed
                or not reference.is_file() or not installed.is_file()):
            return "roots_or_binary_not_independent"
        if os.path.samefile(reference, installed):
            return "binary_inode_alias"
    except (OSError, RuntimeError, ValueError):
        return "binary_or_root_unavailable"
    reference_digest = digest_helper(reference)
    if reference_digest is None:
        return "reference_unqualified"
    installed_digest = digest_helper(installed)
    if installed_digest is None:
        return "installed_unqualified"
    return ("binary_bytes_match_only" if reference_digest == installed_digest
            else "binary_bytes_differ")


def emit(reason):
    print("MEGAQML_F1_HELPER_BINARY_COMPARISON")
    print("REASON=" + reason)
    print("INDEPENDENT_BYTES_MATCH=" +
          ("YES" if reason == "binary_bytes_match_only" else "NO"))
    print("TRUSTED_REFERENCE_BUILD_PROVEN=NO")
    print("ACTUAL_DISPATCHER_SELECTION_PROVEN=NO")
    print("RUNNING_HELPER_PROVEN=NO")
    print("INSTALLED_VENDOR_QUALIFIED=NO")
    print("VENDOR_OR_ACCOUNT_USED=NO")


def main():
    p = argparse.ArgumentParser(description="Offline, owner-selected ELF comparison")
    p.add_argument("--source-root", required=True, type=Path)
    p.add_argument("--expect-sha", required=True)
    p.add_argument("--trusted-build-root", required=True, type=Path)
    p.add_argument("--trusted-built-helper", required=True, type=Path)
    p.add_argument("--installed-helper", required=True, type=Path)
    a = p.parse_args()
    gate = source_gate(a.source_root, a.expect_sha)
    if gate != "source_pin_and_selected_files_clean":
        emit(gate)
        return 21
    result = compare(a.source_root, a.trusted_build_root,
                     a.trusted_built_helper, a.installed_helper)
    emit(result)
    return 0 if result == "binary_bytes_match_only" else 21


if __name__ == "__main__":
    raise SystemExit(main())
