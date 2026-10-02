#!/usr/bin/env python3
"""Read-only postmortem of three previously run, owned PRIVATE Wull boot controls.

Recognizes only known Quickshell startup banner templates. Optionally uses the
documented 'qs log' FILE subcommand to decode the exact retired instance's
bounded .qslog, never launching a new configuration or touching another user's
instance. NEVER prints source lines, paths, identifiers or private log text.
"""
import argparse
import os
from pathlib import Path
import re
import runpy
import shutil
import stat
import subprocess

ROOT = Path(__file__).resolve().parents[1]
FINGERPRINT = "scripts/wull-private-offscreen-boot-fingerprint.py"
FINGERPRINT_BLOB = "2c7a4e069492c1a72d321f91fa509d9d94736002"
SOURCE = "7c9e01dcd3db964a837b12755b088dd2594c9b6d"
LABELS = ("MINIMAL_DYNAMIC_ENV", "FROZEN_DYNAMIC_ENV",
          "FROZEN_HISTORICAL_ENV")
MAX_LOG = 524288
# No untrusted text is ever returned by banner().
BANNER_TOKENS = ("Launching config:", "Shell ID:", "Saving logs to")


def banner(raw, expected_config, runtime_root):
    lines = raw.splitlines()
    if len(lines) != 3:
        return "NONSTANDARD", None
    if not all(token in line for line, token in zip(lines, BANNER_TOKENS)):
        return "NONSTANDARD", None
    # Paths and IDs from arbitrary text are private; use solely for matching.
    path = re.search(r'Launching config:\s*"([^"\r\n]+)"', lines[0])
    identity = re.search(
        r'Shell ID:\s*"[0-9a-f]{16,64}"\s+Path ID\s+"[0-9a-f]{16,64}"',
        lines[1])
    saved = re.search(r'Saving logs to\s*"([^"\r\n]+)"', lines[2])
    if not path or not identity or not saved:
        return "UNVERIFIED_BANNER", None
    # Require the banner to name this exact retained fixture's shell root.
    if Path(path.group(1)) != expected_config:
        return "UNVERIFIED_BANNER", None
    log = Path(saved.group(1))
    if (not log.is_absolute() or log.name != "log.qslog"
            or len(log.parts) < 4 or log.parts[-3] != "by-id"
            or not re.fullmatch(r"[a-zA-Z0-9]{4,64}", log.parts[-2])):
        return "UNVERIFIED_BANNER", None
    # Only allow Quickshell's own by-id runtime folder (not arbitrary files).
    base = runtime_root / "quickshell" / "by-id"
    if log.parent.parent != base:
        return "UNVERIFIED_BANNER", None
    return "STANDARD_3_BANNERS", log


def safe_log(log):
    """Exact path from verified banner only; no search across runtime logs."""
    if not log:
        return "NO_VERIFIED_PATH"
    if log.is_symlink() or not log.is_file():
        return "NOT_AVAILABLE"
    st = log.stat()
    if st.st_uid != os.getuid() or not 0 < st.st_size <= MAX_LOG:
        return "UNSAFE_OR_OVERSIZED"
    return "AVAILABLE"


def qs_log_argv(qs, log):
    """Choose only verified read-file CLI; never invoke a shell startup."""
    try:
        help_result = subprocess.run(
            [qs, "log", "--help"], stdin=subprocess.DEVNULL,
            capture_output=True, text=True, timeout=5)
    except (OSError, subprocess.TimeoutExpired):
        return None
    if help_result.returncode != 0:
        return None
    help_text = help_result.stdout + help_result.stderr
    if "--file" in help_text:
        return [qs, "log", "--file", str(log)]
    # CLI 0.3.x also has builds with a positional FILE parameter.
    if re.search(r"(?im)\b(?:file|log file to read)\b", help_text):
        return [qs, "log", str(log)]
    return None


def decoded_categories(text, classify):
    # Return only fixed vocabulary from previously source-pinned classifier.
    if type(text) is not str or len(text) > MAX_LOG:
        return None
    try:
        rows = classify(text)
    except ValueError:
        return None
    return rows


def git(repo, *args):
    cp = subprocess.run(["git", "-C", str(repo), *args],
                        stdin=subprocess.DEVNULL, capture_output=True,
                        text=True, timeout=5)
    if cp.returncode:
        raise ValueError("unverifiable_private_clone")
    return cp.stdout.strip()


def inspect(scratch):
    if (scratch.name[:15] != "wull-qt-motion."
            or scratch.parent.name != "hadalis"
            or not scratch.parent.parent.name.startswith("wull-qt-state.")
            or scratch.is_symlink() or scratch.parent.is_symlink()
            or scratch.parent.parent.is_symlink()
            or scratch.stat().st_uid != os.getuid()
            or stat.S_IMODE(scratch.stat().st_mode) & 0o077):
        raise ValueError("unsafe_private_scratch")
    repo = scratch / "repo"
    if git(repo, "rev-parse", "HEAD") != SOURCE:
        raise ValueError("unexpected_private_source")
    helper_blob = git(repo, "rev-parse",
                      "HEAD:" + FINGERPRINT)
    if helper_blob != FINGERPRINT_BLOB:
        raise ValueError("classifier_pin_changed")
    helper = runpy.run_path(str(repo / FINGERPRINT),
                            run_name="wull_private_qslog_classifier")
    if git(repo, "remote", "get-url", "origin") not in helper["SAFE_ORIGINS"]:
        raise ValueError("unsafe_private_origin")
    runtime = Path(os.environ.get("XDG_RUNTIME_DIR")
                   or "/run/user/" + str(os.getuid()))
    if not runtime.is_absolute() or not runtime.is_dir() or runtime.is_symlink():
        raise ValueError("runtime_root_unverified")
    if runtime.stat().st_uid != os.getuid():
        raise ValueError("runtime_owner_unverified")
    classify = helper["classify"]
    qs = shutil.which("qs") or shutil.which("quickshell")
    print("SOURCE_SHA=" + SOURCE)
    for label in LABELS:
        label_dir = scratch / "boot-controls" / label.lower()
        control_log = label_dir / "control.private.log"
        if (label_dir.is_symlink() or control_log.is_symlink()
                or not control_log.is_file()
                or control_log.stat().st_uid != os.getuid()
                or not 0 < control_log.stat().st_size <= 262144):
            print(label + "_BANNER=CONTROL_LOG_UNAVAILABLE")
            continue
        raw = control_log.read_text(encoding="utf-8", errors="replace")
        expected = label_dir / "shell" / "shell.qml"
        result, internal_log = banner(raw, expected, runtime)
        print(label + "_BANNER=" + result)
        if result != "STANDARD_3_BANNERS":
            continue
        print(label + "_INTERNAL_LOG=" + safe_log(internal_log))
        if safe_log(internal_log) != "AVAILABLE":
            continue
        if not qs:
            print(label + "_DECODER=CLI_UNAVAILABLE")
            continue
        argv = qs_log_argv(qs, internal_log)
        if argv is None:
            print(label + "_DECODER=CLI_UNVERIFIED")
            continue
        # Explicit FILE read of the captured instance only; no follow, no
        # config selection, no process restart or new shell instance.
        env = dict(os.environ)
        for name in ("WAYLAND_DISPLAY", "DISPLAY", "NIRI_SOCKET",
                     "QS_CONFIG_PATH", "QS_CONFIG_NAME", "QS_MANIFEST"):
            env.pop(name, None)
        env["QT_QPA_PLATFORM"] = "offscreen"
        try:
            decoded = subprocess.run(
                argv, cwd=ROOT, env=env, stdin=subprocess.DEVNULL,
                capture_output=True, text=True, timeout=5)
        except (OSError, subprocess.TimeoutExpired):
            print(label + "_DECODER=UNAVAILABLE")
            continue
        data = decoded.stdout + decoded.stderr
        rows = decoded_categories(data, classify)
        if decoded.returncode != 0 or rows is None:
            print(label + "_DECODER=INCONCLUSIVE")
            continue
        print(label + "_DECODER=DECODED")
        print(label + "_DECODED_LINES=" + str(len(rows)))
        for index, (classes, terms, band) in enumerate(rows[-8:], 1):
            print(label + "_TAIL_" + str(index) + "_CLASSES="
                  + ",".join(classes))
            print(label + "_TAIL_" + str(index) + "_TERMS="
                  + ",".join(terms))
            print(label + "_TAIL_" + str(index) + "_LENGTH=" + band)
    print("GATE=PRIVATE_EXISTING_QSLOG_POSTMORTEM_ONLY")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--scratch", required=True, type=Path)
    args = parser.parse_args()
    try:
        inspect(args.scratch.absolute())
    except (ValueError, OSError, subprocess.TimeoutExpired):
        print("GATE=PRIVATE_EXISTING_QSLOG_POSTMORTEM_UNAVAILABLE")
        raise SystemExit(1)


if __name__ == "__main__":
    main()
