#!/usr/bin/env python3
"""Owner-local OFFLINE byte-identity prerequisite for MegaQML F1 visual review.

This checks ten source/deployed UI files only. It cannot establish which
Quickshell config a running process actually loaded, Rust helper provenance,
real pointer behavior, or installed MEGAcmd/account capability.
"""
import argparse
import hashlib
import os
from pathlib import Path
import re
import subprocess

FILES = (
    "settings.qml",
    "waffleSettings.qml",
    "modules/settings/CloudStorageConfig.qml",
    "modules/waffle/settings/pages/WCloudStoragePage.qml",
    "modules/settings/SettingsPageHost.qml",
    "modules/waffle/settings/WSettingsContent.qml",
    "services/deferred/CloudStorageService.qml",
    "services/deferred/CloudStorageStaticProtocol.js",
    "services/deferred/CloudStoragePreflightProtocol.js",
    "scripts/native-dispatch",
)
SCRIPT = "scripts/megaqml-f1-deployed-source-identity.py"
MAX_FILE_BYTES = 4 * 1024 * 1024


def digest(root, rel):
    """Resolve only descendants of the selected root; never publish bytes."""
    try:
        target = (root / rel).resolve(strict=True)
        if not target.is_relative_to(root) or not target.is_file():
            return None
        if target.stat().st_size > MAX_FILE_BYTES:
            return None
        h = hashlib.sha256()
        size = 0
        with target.open("rb") as source:
            while True:
                chunk = source.read(65536)
                if not chunk:
                    return h.digest()
                size += len(chunk)
                if size > MAX_FILE_BYTES:
                    return None
                h.update(chunk)
    except (OSError, ValueError, RuntimeError):
        return None


def git(root, *args):
    try:
        done = subprocess.run(
            ["git", "-c", "core.fsmonitor=false", "-C", str(root), *args],
            capture_output=True, check=False, timeout=8,
            env={**os.environ, "GIT_OPTIONAL_LOCKS": "0"},
        )
        return done.stdout if done.returncode == 0 else None
    except (OSError, subprocess.TimeoutExpired):
        return None


def assess(source, deployed, expected):
    if not re.fullmatch(r"[0-9a-f]{40}", expected):
        return "invalid_pin", 0, 0
    try:
        source = source.resolve(strict=True)
        deployed = deployed.resolve(strict=True)
        if not source.is_dir() or not deployed.is_dir():
            return "directory_unavailable", 0, 0
        # Reject running a different/stale copy of this validation script.
        if Path(__file__).resolve() != (source / SCRIPT).resolve(strict=True):
            return "script_source_mismatch", 0, 0
    except (OSError, RuntimeError):
        return "directory_unavailable", 0, 0
    top = git(source, "rev-parse", "--show-toplevel")
    head = git(source, "rev-parse", "--verify", "HEAD")
    if top is None or head is None or top.strip() != os.fsencode(str(source)):
        return "source_unverified", 0, 0
    if head.decode("ascii", "ignore").strip() != expected:
        return "source_head_mismatch", 0, 0
    dirty = git(source, "status", "--porcelain", "--untracked-files=no",
                "--", SCRIPT, *FILES)
    if dirty is None or dirty.strip():
        return "source_files_dirty", 0, 0
    matched = 0
    unavailable = 0
    for rel in FILES:
        original = digest(source, rel)
        target = digest(deployed, rel)
        if original is None or target is None:
            unavailable += 1
        elif original == target:
            matched += 1
    if unavailable:
        return "file_unavailable", matched, unavailable
    if matched != len(FILES):
        return "deployed_mismatch", matched, 0
    return "static_bytes_match", matched, 0


def main():
    p = argparse.ArgumentParser(description="Offline static identity only")
    p.add_argument("--source-root", required=True, type=Path)
    p.add_argument("--deployed-config-root", required=True, type=Path)
    p.add_argument("--expect-sha", required=True)
    args = p.parse_args()
    reason, matched, unavailable = assess(
        args.source_root, args.deployed_config_root, args.expect_sha)
    print("MEGAQML_F1_DEPLOYED_SOURCE_IDENTITY")
    print("REASON=" + reason)
    print("MATCHED_FILE_COUNT=" + str(matched))
    print("UNAVAILABLE_FILE_COUNT=" + str(unavailable))
    print("TOTAL_FILE_COUNT=" + str(len(FILES)))
    print("STATIC_BYTES_MATCH=" + str(reason == "static_bytes_match").upper())
    print("RUNNING_PROCESS_CONFIG_PROVEN=NO")
    print("INSTALLED_HELPER_PROVEN=NO")
    print("REAL_DESKTOP_VISUAL_ACCEPTED=NO")
    print("VENDOR_OR_ACCOUNT_USED=NO")
    return 0 if reason == "static_bytes_match" else 21


if __name__ == "__main__":
    raise SystemExit(main())
