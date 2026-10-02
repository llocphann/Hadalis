#!/usr/bin/env python3
"""Read-only, category-only fingerprint for a retained PRIVATE Wull Qt boot log.

Never starts Qt, changes a repo, outputs original log lines, or infers an exit
code from log text. Intended for a previously preserved owned scratch clone.
"""
import argparse
import os
from pathlib import Path
import re
import stat
import subprocess

SAFE_ORIGINS = {
    "git@github.com:llocphann/Hadalis.git",
    "git@github.com:llocphann/Hadalis",
    "https://github.com/llocphann/Hadalis.git",
    "https://github.com/llocphann/Hadalis",
    "ssh://git@github.com/llocphann/Hadalis.git",
    "ssh://git@github.com/llocphann/Hadalis",
}
# Every printed class is authored below; no untrusted log content is returned.
PATTERNS = (
    ("CLI_OR_USAGE", r"\b(?:usage|unknown option|unrecognized option|unknown argument|invalid argument|unexpected argument|--help)\b"),
    ("CONFIG_RESOLUTION", r"\b(?:configuration|config(?:uration)?\s+(?:file|path|directory)|no configuration|config not found)\b"),
    ("FILE_OR_PERMISSION", r"\b(?:no such file|does not exist|permission denied|access denied|not a directory|cannot open|could not open)\b"),
    ("QML_LOAD", r"\b(?:failed to load|could not load|unable to load|failed to instantiate|cannot create|is not a type)\b"),
    ("QML_IMPORT", r"\b(?:module .{0,100}?(?:not found|not installed)|import path|qmldir|unresolved import)\b"),
    ("QML_DIAGNOSTIC", r"\b(?:qqml|qmlscene|referenceerror|typeerror|syntaxerror|binding loop|component)\b"),
    ("QT_PLATFORM", r"\b(?:qt\.qpa|platform plugin|offscreen|wayland display|failed to create window)\b"),
    ("INSTANCE_OR_IPC", r"\b(?:instance|ipc|socket|session bus|dbus|d-bus|already running)\b"),
    ("DYNAMIC_LIBRARY", r"\b(?:shared library|undefined symbol|symbol lookup|libqt|libc[.]so)\b"),
    ("PROCESS_FAILURE", r"\b(?:panic|aborted|fatal|crash|segmentation|assertion|exited|terminated|killed)\b"),
    ("LOG_SEVERITY", r"\b(?:error|failed|warning|critical|trace|debug)\b"),
    ("QUICKSHELL_MESSAGE", r"\b(?:quickshell|shellroot)\b"),
)
# Only these static words can be printed, not arbitrary path or QML content.
SAFE_TERMS = ("quickshell", "configuration", "config", "qml", "shellroot",
              "option", "usage", "directory", "module", "launch",
              "instance", "offscreen", "wayland", "dbus", "warning",
              "critical", "error", "failed", "version", "plugin", "file")
MAX_BYTES = 524288


def classify(raw):
    """Return a fixed-schema fingerprint with zero untrusted text fields."""
    if type(raw) is not str:
        raise ValueError("invalid_private_log_text")
    lines = raw.splitlines()
    if len(lines) > 1024:
        raise ValueError("private_log_too_many_lines")
    out = []
    for line in lines:
        classes = [name for name, pattern in PATTERNS
                   if re.search(pattern, line, re.IGNORECASE)]
        terms = [term.upper() for term in SAFE_TERMS
                 if re.search(r"(?<![A-Za-z])" + re.escape(term) + r"(?![A-Za-z])",
                              line, re.IGNORECASE)]
        band = ("SHORT" if len(line) < 64 else "MEDIUM" if len(line) < 160
                else "LONG" if len(line) < 512 else "VERY_LONG")
        out.append((classes or ["UNCLASSIFIED"], terms or ["NONE"], band))
    return out


def git_read(repo, *args):
    cp = subprocess.run(["git", "-C", str(repo), *args], capture_output=True,
                        text=True, timeout=7)
    if cp.returncode:
        raise ValueError("original_private_clone_unavailable")
    return cp.stdout.strip()


def inspect(scratch, expected):
    if not re.fullmatch(r"[0-9a-f]{40}", expected):
        raise ValueError("invalid_expected_source")
    # Reject arbitrary paths, symlinks and other users' retained private logs.
    if (scratch.name[:15] != "wull-qt-motion."
            or scratch.parent.name != "hadalis"
            or not scratch.parent.parent.name.startswith("wull-qt-state.")
            or scratch.is_symlink() or scratch.parent.is_symlink()
            or scratch.parent.parent.is_symlink()
            or scratch.stat().st_uid != os.getuid()
            or stat.S_IMODE(scratch.stat().st_mode) & 0o077):
        raise ValueError("not_an_owned_private_wull_scratch")
    repo = scratch / "repo"
    log = scratch / "dynamic-qml" / "dynamic.private.log"
    if (repo.is_symlink() or log.is_symlink() or not log.is_file()
            or log.stat().st_uid != os.getuid()
            or not 0 < log.stat().st_size <= MAX_BYTES):
        raise ValueError("private_log_outside_reviewed_bounds")
    if git_read(repo, "rev-parse", "HEAD") != expected:
        raise ValueError("wrong_original_clone_source")
    if git_read(repo, "remote", "get-url", "origin") not in SAFE_ORIGINS:
        raise ValueError("unrecognized_private_clone_origin")
    raw = log.read_text(encoding="utf-8", errors="replace")
    rows = classify(raw)
    print("SOURCE_SHA=" + expected)
    print("PRIVATE_LOG_BYTES=" + str(log.stat().st_size))
    print("PRIVATE_LOG_LINES=" + str(len(rows)))
    print("PRIVATE_LOG_WULL_MARKERS=" +
          str(sum("WULL_OFFSCREEN_DYNAMIC_" in line for line in raw.splitlines())))
    for n, (classes, terms, band) in enumerate(rows[:16], 1):
        print("LINE_" + str(n) + "_CLASSES=" + ",".join(classes))
        print("LINE_" + str(n) + "_SAFE_TERMS=" + ",".join(terms))
        print("LINE_" + str(n) + "_LENGTH_BAND=" + band)
    print("OLD_CHILD_EXIT_CODE=NOT_RECOVERABLE_FROM_LOG")
    print("GATE=READONLY_BOOT_FINGERPRINT_COMPLETE")


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--scratch", required=True, type=Path)
    p.add_argument("--source", required=True)
    args = p.parse_args()
    try:
        inspect(args.scratch.absolute(), args.source)
    except (ValueError, OSError, subprocess.TimeoutExpired):
        print("GATE=READONLY_BOOT_FINGERPRINT_UNAVAILABLE")
        raise SystemExit(1)


if __name__ == "__main__":
    main()
