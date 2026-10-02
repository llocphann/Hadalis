#!/usr/bin/env python3
"""READ-ONLY, private, allowlisted review of retained minimal-QS debug logs.

Does not run Qt, Quickshell, coredumpctl or another probe. Identifies real
platform-loader failure patterns separately from benign QT_DEBUG_PLUGINS lines.
Never displays raw stdout, paths, environment values or plugin metadata.
"""
import argparse
import os
from pathlib import Path
import re
import stat
import subprocess

OLD_SOURCE = "284001594ca472ec6a098956754ad13bfa977e7a"
OLD_PROBE_PATH = "scripts/wull-private-minimal-qs-bootstrap.py"
OLD_PROBE_BLOB = "edd28683dc1ce679f24aa460e914cfad5abdc0a6"
LABELS = ("OFFSCREEN_FILE", "OFFSCREEN_DIRECTORY", "MINIMAL_FILE")
MAX_BYTES = 524288
SAFE_ORIGINS = {
    "git@github.com:llocphann/Hadalis.git",
    "git@github.com:llocphann/Hadalis",
    "https://github.com/llocphann/Hadalis.git",
    "https://github.com/llocphann/Hadalis",
    "ssh://git@github.com/llocphann/Hadalis.git",
    "ssh://git@github.com/llocphann/Hadalis",
}
# Patterns match explicit FAILURES, not the normal Qt debug plugin chatter.
FAILURES = (
    ("QPA_CANNOT_FIND", r"could not find the qt platform plugin"),
    ("QPA_CANNOT_LOAD", r"could not load the qt platform plugin"),
    ("QPA_NO_PLATFORM_INITIALIZED", r"no qt platform plugin could be initialized"),
    ("QPA_PLATFORM_CREATION_FAILED", r"failed to (?:create|initialize) (?:a |the )?(?:qt )?(?:qpa |platform )?integration"),
    ("LIBRARY_UNRESOLVED", r"cannot (?:load|open) (?:shared )?librar|undefined symbol|symbol lookup error|cannot open shared object file"),
    ("QT_PLUGIN_VERSION_MISMATCH", r"(?:qt|plugin).{0,100}?(?:incompatible|version mismatch|cannot mix incompatible|higher qt version)"),
    ("QML_LOAD_FAILURE", r"(?:module .{0,120}?(?:not installed|not found)|failed to load configuration|error loading qml|syntaxerror|referenceerror|typeerror)"),
    ("QT_FATAL", r"\bfatal(?: error)?\b|\bassertion\b|ASSERT:"),
    ("EXPLICIT_ABORT", r"\b(?:aborted|segmentation fault|core dumped|stack smashing detected)\b"),
    ("RESOURCE_LIMIT", r"\b(?:file size limit exceeded|sigxfsz|no space left on device)\b"),
    ("FILE_OR_ACCESS", r"\b(?:permission denied|access denied|no such file or directory)\b"),
)
INFO_EVENTS = (
    ("QT_PLUGIN_DISCOVERY", r"checking directory path|looking at|found metadata in lib|got keys from plugin meta data|plugin meta data found"),
    ("QT_PLUGIN_LOADED", r"loaded library |loaded plugin"),
    ("QT_PLUGIN_UNLOADED", r"unloaded library "),
    ("QT_PLUGIN_LOAD_ATTEMPT", r"cannot load library|attempting to load|trying to load"),
    ("QS_STANDARD_BANNER", r"launching config:|shell id:|saving logs to"),
    ("QML_COMPLETED_MARKER", r"WULL_MINIMAL_QML_COMPONENT_LOADED"),
    ("CHILD_EXIT_MARKER", r"WULL_MINIMAL_CHILD_EXIT="),
)
SIGNAL_LITERALS = ("SIGABRT", "SIGSEGV", "SIGBUS", "SIGILL", "SIGTRAP",
                   "SIGXFSZ", "SIGTERM", "SIGKILL")
CHILD_RE = re.compile(r"(?m)^WULL_MINIMAL_CHILD_EXIT=(ZERO|NONZERO|SIGNAL|TIMEOUT)$")


def classify(raw):
    """Return fixed-schema categories only, no original substrings."""
    if type(raw) is not str or len(raw.encode("utf-8")) > MAX_BYTES:
        raise ValueError("unsafe_private_log")
    lines = raw.splitlines()
    if len(lines) > 15000:
        raise ValueError("unbounded_private_lines")
    failures = [label for label, pattern in FAILURES
                if re.search(pattern, raw, re.I)]
    events = [label for label, pattern in INFO_EVENTS
              if re.search(pattern, raw, re.I)]
    explicit_signals = [sig for sig in SIGNAL_LITERALS
                        if re.search(r"\b" + sig + r"\b", raw, re.I)]
    child = CHILD_RE.findall(raw)
    # Only predefined labels derived from final six log lines are returned.
    def line_stage(line):
        matches = [label for label, pattern in INFO_EVENTS
                   if re.search(pattern, line, re.I)]
        matches += [label for label, pattern in FAILURES
                    if re.search(pattern, line, re.I)]
        return matches or ["UNCLASSIFIED"]
    tail = [",".join(line_stage(line)) for line in lines[-6:]]
    # Do not interpret "qt.qpa.plugin" alone as an error: Qt prints it while
    # searching for, successfully loading, and unloading plugins.
    return {
        "LINES": len(lines),
        "QML_MARKER": "ONE" if sum("WULL_MINIMAL_QML_COMPONENT_LOADED" in line
                             for line in lines) == 1 else
                      "NONE" if not any("WULL_MINIMAL_QML_COMPONENT_LOADED" in line
                                        for line in lines) else "MULTIPLE",
        "CHILD_EXIT": child[0] if len(child) == 1 else "NOT_UNIQUELY_RECORDED",
        "EXPLICIT_SIGNALS": ",".join(explicit_signals) if explicit_signals else "NONE_IN_LOG",
        "FAILURES": ",".join(failures) if failures else "NO_EXPLICIT_FAILURE_PATTERN",
        "QT_EVENTS": ",".join(events) if events else "NONE",
        "TAIL": tail,
    }


def git(repo, *args):
    p = subprocess.run(["git", "-C", str(repo), *args],
                       stdin=subprocess.DEVNULL, capture_output=True,
                       text=True, timeout=8)
    if p.returncode:
        raise ValueError("unverified_private_clone")
    return p.stdout.strip()


def validate(scratch):
    if (scratch.name[:15] != "wull-qt-motion."
            or scratch.parent.name != "hadalis"
            or not scratch.parent.parent.name.startswith("wull-qt-state.")
            or any(p.is_symlink() for p in
                   (scratch, scratch.parent, scratch.parent.parent))):
        raise ValueError("untrusted_private_path")
    for p in (scratch, scratch.parent, scratch.parent.parent):
        st = p.stat()
        if (not p.is_dir() or st.st_uid != os.getuid()
                or stat.S_IMODE(st.st_mode) & 0o077):
            raise ValueError("private_directory_not_owned")
    repo = scratch / "repo"
    if repo.is_symlink() or not repo.is_dir():
        raise ValueError("original_clone_missing")
    if (git(repo, "rev-parse", "HEAD") != OLD_SOURCE
            or git(repo, "rev-parse", "HEAD:" + OLD_PROBE_PATH) != OLD_PROBE_BLOB
            or git(repo, "remote", "get-url", "origin") not in SAFE_ORIGINS):
        raise ValueError("unreviewed_original_source")
    return repo


def review(scratch):
    validate(scratch)
    print("SOURCE_SHA=" + OLD_SOURCE)
    for name in LABELS:
        directory = scratch / "minimal-qs-bootstrap" / name.lower()
        logfile = directory / "minimal.private.log"
        if (directory.is_symlink() or logfile.is_symlink()
                or not logfile.is_file()
                or logfile.stat().st_uid != os.getuid()
                or not 0 < logfile.stat().st_size <= MAX_BYTES):
            print(name + "_STATUS=LOG_UNAVAILABLE")
            continue
        raw_bytes = logfile.read_bytes()
        if len(raw_bytes) > MAX_BYTES:
            print(name + "_STATUS=LOG_UNAVAILABLE")
            continue
        raw = raw_bytes.decode("utf-8", errors="replace")
        try:
            result = classify(raw)
        except ValueError:
            print(name + "_STATUS=LOG_UNCLASSIFIABLE")
            continue
        print(name + "_STATUS=CLASSIFIED")
        print(name + "_BYTES=" + str(len(raw_bytes)))
        print(name + "_LINES=" + str(result["LINES"]))
        print(name + "_NEAR_SIZE_LIMIT=" +
              ("YES" if len(raw_bytes) >= MAX_BYTES - 4096 else "NO"))
        print(name + "_ENDS_NEWLINE=" +
              ("YES" if raw_bytes.endswith(b"\n") else "NO"))
        for field in ("QML_MARKER", "CHILD_EXIT", "EXPLICIT_SIGNALS",
                      "FAILURES", "QT_EVENTS"):
            print(name + "_" + field + "=" + result[field])
        for n, labels in enumerate(result["TAIL"], 1):
            print(name + "_TAIL_" + str(n) + "=" + labels)
    print("GATE=READ_ONLY_EXISTING_MINIMAL_LOGS_CLASSIFIED")


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--scratch", type=Path, required=True)
    args = p.parse_args()
    try:
        review(args.scratch.absolute())
    except (ValueError, OSError, subprocess.TimeoutExpired):
        print("GATE=READ_ONLY_EXISTING_MINIMAL_LOGS_UNAVAILABLE")
        raise SystemExit(1)


if __name__ == "__main__":
    main()
