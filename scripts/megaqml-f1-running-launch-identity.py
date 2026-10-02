#!/usr/bin/env python3
"""Offline F1 corroboration of one owner-selected standalone Quickshell PID.

Never interprets launch arguments as proof of loaded QML, Rust provenance,
rendering, or installed MEGAcmd behavior; does not discover or contact vendor.
"""
import argparse
import importlib.util
import os
from pathlib import Path
import re
import stat
import subprocess

SCRIPT = "scripts/megaqml-f1-running-launch-identity.py"
ENTRY = {"material": "settings.qml", "waffle": "waffleSettings.qml"}


def capped(path, limit):
    with path.open("rb") as handle:
        data = handle.read(limit + 1)
    if not data or len(data) > limit:
        raise ValueError("unavailable")
    return data


def starttime(value):
    match = re.match(rb"^[0-9]+ \(.+\) ", value)
    if not match:
        return None
    fields = value[match.end():].split()
    return int(fields[19]) if len(fields) > 19 and fields[19].isdigit() else None


def uid_fields(value):
    rows = [line.split() for line in value.splitlines() if line.startswith(b"Uid:")]
    if len(rows) != 1 or len(rows[0]) != 5:
        return None
    try:
        return tuple(int(n) for n in rows[0][1:])
    except ValueError:
        return None


def snapshot(proc):
    return (capped(proc / "stat", 4096),
            capped(proc / "status", 65536),
            capped(proc / "cmdline", 4096),
            os.readlink(proc / "exe"))


def assess_running(root, family, pid, proc_root=Path("/proc"), uid=None):
    if family not in ENTRY or type(pid) is not int or pid <= 0:
        return "invalid_selection"
    uid = os.getuid() if uid is None else uid
    try:
        root = Path(root).resolve(strict=True)
        entry = (root / ENTRY[family]).resolve(strict=True)
        if not root.is_dir() or not entry.is_file() or not entry.is_relative_to(root):
            return "deployed_entry_unavailable"
        proc = proc_root / str(pid)
        before = snapshot(proc)
        middle = snapshot(proc)
        btime = starttime(before[0])
        if (btime is None or btime != starttime(middle[0])
                or before[2:] != middle[2:]
                or uid_fields(before[1]) != uid_fields(middle[1])):
            return "process_identity_unstable"
        if uid_fields(before[1]) != (uid,) * 4:
            return "process_owner_unqualified"
        exe = Path(before[3])
        if (exe.name not in ("qs", "quickshell") or not exe.is_file()
                or not exe.stat().st_mode & (stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)):
            return "process_executable_unqualified"
        raw = before[2]
        if not raw.endswith(b"\x00"):
            return "launch_arguments_unqualified"
        argv = raw[:-1].split(b"\x00")
        # Current scripts/inir launcher uses exec qs -n -p "$dir/$entry".
        if len(argv) != 4 or argv[1:3] != [b"-n", b"-p"]:
            return "launch_arguments_unqualified"
        selected = Path(os.fsdecode(argv[3]))
        if not selected.is_absolute() or selected.resolve(strict=True) != entry:
            return "launch_arguments_unqualified"
        after = snapshot(proc)
        if (starttime(after[0]) != btime or after[2:] != before[2:]
                or uid_fields(after[1]) != uid_fields(before[1])):
            return "process_identity_unstable"
    except (OSError, ValueError, RuntimeError):
        return "process_unavailable"
    return "standalone_launch_path_observed"


def emit(reason):
    print("MEGAQML_F1_RUNNING_LAUNCH_OBSERVATION")
    print("REASON=" + reason)
    print("STANDALONE_LAUNCH_PATH_OBSERVED=" +
          ("YES" if reason == "standalone_launch_path_observed" else "NO"))
    print("RUNNING_QML_BYTES_PROVEN=NO")
    print("INSTALLED_RUST_HELPER_PROVEN=NO")
    print("PHYSICAL_DESKTOP_ACCEPTED=NO")
    print("VENDOR_OR_ACCOUNT_USED=NO")


def main():
    p = argparse.ArgumentParser(description="Selected-PID offline F1 launch corroboration")
    p.add_argument("--source-root", required=True, type=Path)
    p.add_argument("--deployed-config-root", required=True, type=Path)
    p.add_argument("--expect-sha", required=True)
    p.add_argument("--family", required=True, choices=sorted(ENTRY))
    p.add_argument("--pid", required=True, type=int)
    args = p.parse_args()
    try:
        source = args.source_root.resolve(strict=True)
        if Path(__file__).resolve() != (source / SCRIPT).resolve(strict=True):
            emit("script_source_mismatch")
            return 21
        status = subprocess.run(
            ["git", "-C", str(source), "status", "--porcelain",
             "--untracked-files=no", "--", SCRIPT],
            capture_output=True, timeout=8, check=False,
            env={**os.environ, "GIT_OPTIONAL_LOCKS": "0"})
        if status.returncode or status.stdout.strip():
            emit("script_source_dirty")
            return 21
        helper = source / "scripts/megaqml-f1-deployed-source-identity.py"
        spec = importlib.util.spec_from_file_location("f1static", helper)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        reason, matched, missing = module.assess(
            source, args.deployed_config_root, args.expect_sha)
        if reason != "static_bytes_match" or matched != 10 or missing:
            emit("static_identity_unqualified")
            return 21
        result = assess_running(args.deployed_config_root, args.family, args.pid)
    except (OSError, ValueError, RuntimeError, ImportError, subprocess.TimeoutExpired):
        result = "prerequisite_unavailable"
    emit(result)
    return 0 if result == "standalone_launch_path_observed" else 21


if __name__ == "__main__":
    raise SystemExit(main())
