#!/usr/bin/env python3
"""Classify a PREVIOUS owned failed fake-only action without re-executing it.

A deliberate nonzero EXIT is a fixed stage code, NOT a new test failure.
No private traceback, file path, code snippet or raw stdout leaves this process.
"""
import json
import os
from pathlib import Path
import re
import sys

JOB = "JOB-WULL-MATRIX-INSPECT-P1E0042-20261002-04"
SHA = "ac699871dd92450bed03af2c8b6e5d78cb06a7a8"
CLASS = {31: "STATIC_GUARD", 32: "SETUP_OR_GENERATOR",
         33: "FOUR_CELL_POSITIVE", 34: "MONOCHROME_NEGATIVE",
         35: "MISSING_CELL_NEGATIVE", 36: "BAD_PNG_NEGATIVE",
         37: "OTHER_OR_UNRECOGNIZED", 39: "RECEIPT_UNAVAILABLE"}


def classify_private(text):
    """Return an ALLOWLISTED stage code from a bounded private traceback."""
    if not isinstance(text, str) or len(text) > 8192:
        return 37
    # Match test filename literally; do not expose private path/stack.
    lines = re.findall(
        r'File "[^"\n]{0,768}(?:^|/)test-wull-existing-matrix-evidence\.py", line (\d{1,3})',
        text, flags=re.M)
    # The filename is also allowed WITHOUT any path.
    if not lines:
        lines = re.findall(
            r'File "test-wull-existing-matrix-evidence\.py", line (\d{1,3})',
            text)
    if not lines:
        # Some Python traceback formats put the basename after <frozen runpy>.
        lines = re.findall(
            r'test-wull-existing-matrix-evidence\.py", line (\d{1,3})',
            text)
    if not lines:
        return 37
    line = int(lines[-1])
    if 15 <= line <= 28:
        return 31
    if 29 <= line <= 60:
        return 32
    if 61 <= line <= 68:
        return 33
    if 69 <= line <= 71:
        return 34
    if 72 <= line <= 77:
        return 35
    if 78 <= line <= 82:
        return 36
    return 37


def detail_private(text):
    """Encodes exact old positive-test line plus safe exception category.

    For OLD lines 61..68 only:
    exit = 100 + (test_line - 61) * 10 + exception_class.
    exception_class: 1 AssertionError, 2 ValueError, 3 TypeError,
    4 IndexError, 5 KeyError, 6 NameError, 7 RuntimeError, 9 OTHER.
    No traceback text or exception message is ever emitted.
    """
    if classify_private(text) != 33:
        return 39
    lines = re.findall(
        r'test-wull-existing-matrix-evidence\.py", line (\d{1,3})',
        text)
    if not lines:
        return 39
    line = int(lines[-1])
    if line not in range(61, 69):
        return 39
    end = text.strip().splitlines()[-1].strip()
    klass = end.split(":", 1)[0].strip()
    enum = {"AssertionError": 1, "ValueError": 2, "TypeError": 3,
            "IndexError": 4, "KeyError": 5, "NameError": 6,
            "RuntimeError": 7}.get(klass, 9)
    return 100 + (line - 61) * 10 + enum


def fixed_reason_private(text):
    """Pre-reviewed reason labels only; never output freeform stderr."""
    if classify_private(text) != 33:
        return 199
    if not isinstance(text, str) or len(text) > 8192:
        return 199
    tail = text.strip().splitlines()[-1].strip()
    reasons = (
        "PNG_BYTES_UNREVIEWED", "PNG_SIGNATURE_INVALID", "PNG_CHUNK_INVALID",
        "PNG_RGBA_FORMAT_REQUIRED", "PNG_METADATA_ORDER_INVALID",
        "PNG_IDAT_ORDER_INVALID", "PNG_END_INVALID", "PNG_INCOMPLETE",
        "PNG_DECOMPRESSED_SIZE_INVALID", "PNG_ZLIB_INVALID",
        "PNG_FILTER_INVALID", "RGBA_UNQUALIFIED", "PNG_HEADER_INVALID",
        "PNG_CRC_INVALID", "PNG_UNSUPPORTED_CHUNK", "PNG_TRUNCATED",
        "PNG_IDAT_TOO_LARGE", "PNG_ZLIB_INVALID",
    )
    for index, token in enumerate(reasons):
        if tail.endswith(": " + token):
            return 131 + index
    return 199


def main():
    if sys.argv[1:] not in (["--prior-action-only"], ["--detail-only"],
                            ["--fixed-reason-only"]):
        return 39
    state = Path(os.environ.get(
        "XDG_STATE_HOME", str(Path.home() / ".local/state")))
    folder = state / "hadalis-automation" / "worker" / "actions" / JOB
    action = folder / "action-0.json"
    if not action.is_file() or action.is_symlink():
        return 39
    meta = action.stat()
    if meta.st_uid != os.getuid() or meta.st_mode & 0o077:
        return 39
    raw = action.read_bytes()
    if not raw or len(raw) > 64 * 1024:
        return 39
    record = json.loads(raw)
    result = record.get("result", {})
    if (record.get("phase") != "finished"
            or result.get("evidence_id") != JOB + ":0"
            or result.get("source_sha") != SHA
            or result.get("exit_code") != 1
            or result.get("timed_out") is not False):
        return 39
    if sys.argv[1:] == ["--fixed-reason-only"]:
        return fixed_reason_private(result.get("stderr", ""))
    if sys.argv[1:] == ["--detail-only"]:
        return detail_private(result.get("stderr", ""))
    return classify_private(result.get("stderr", ""))


if __name__ == "__main__":
    try:
        stage = main()
    except (OSError, UnicodeError, ValueError, KeyError, TypeError):
        stage = 39
    # Deliberately publish category VIA EXIT CODE ONLY: the Git worker
    # metadata allowlist already exposes it. Zero stdout/stderr and no raw
    # diagnostic trace cross the boundary.
    sys.exit(stage if stage in CLASS or 100 <= stage <= 179
             or 131 <= stage <= 148 or stage == 199 else 39)
