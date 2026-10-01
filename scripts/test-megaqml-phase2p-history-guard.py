#!/usr/bin/env python3
"""Strict Wull-only or source-verified Phase 2p evidence dev ancestry guard."""
from pathlib import Path
import re
import subprocess
import sys

EXPECTED_TESTS = """
megaqml_phase2_contract settings_navigation megaqml_waffle_navigation
megaqml_static_protocol megaqml_quickshell_diagnostics
megaqml_fake_dispatch_fixture megaqml_ui_component_fixture
megaqml_real_host_route_preflight megaqml_real_host_fixture
megaqml_race_repeat_contract quickshell_baseline quickshell_service_dormant
quickshell_active_present quickshell_active_missing quickshell_reject_wrong_id
quickshell_reject_unsafe_secret quickshell_reject_malformed
quickshell_exit_failure quickshell_deadline_reap quickshell_refresh_coalesce
quickshell_refresh_stale_reacquire quickshell_recover_exit
quickshell_recover_timeout quickshell_ui_material quickshell_ui_waffle
quickshell_ui_shared quickshell_ui_race megaqml_race_repeatability
quickshell_ui_host megaqml_rust_build megaqml_fake_vendor_boundary
qml_minimal qml_modern_syntax qml_baseline qml_service qml_page
qml_waffle_baseline qml_waffle_page qml_waffle_entry qml_waffle_content
""".split()
assert len(EXPECTED_TESTS) == 40 and len(set(EXPECTED_TESTS)) == 40
ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = re.compile(
    r"docs/evidence/megaqml/phase2p-([0-9a-f]{12})-"
    r"(20[0-9]{6}T[0-9]{6}Z)\.md")
SHA = re.compile(r"[0-9a-f]{40}")
ROW = re.compile(r"\| ([a-z][a-z0-9_]*) \| (PASS|FAIL|SKIP) \| "
                 r"([0-9]{1,3}) \| ([0-9a-f]{40}) \|")


class Rejected(Exception):
    pass


def git(*args):
    return subprocess.check_output(
        ["git", "-C", str(ROOT), *args], stderr=subprocess.DEVNULL)


def ancestor(old, new):
    return subprocess.run(
        ["git", "-C", str(ROOT), "merge-base", "--is-ancestor", old, new],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0


def wull(path):
    return (path.startswith(("docs/wull-", "scripts/wull-",
                             "scripts/test-wull-", "modules/abyss/"))
            or path == "docs/WULL_NESTED_POINTER_ACCEPTANCE_DESIGN.md"
            or path == "to-do/cloud-bot/ABYSS_WATER_DROPLET_COMPANION.md")


def changes(base, tip):
    parts = git("diff", "--name-status", "-z", base, tip, "--").split(b"\0")
    if parts[-1:] == [b""]:
        parts.pop()
    if len(parts) % 2:
        raise Rejected("malformed diff")
    result = []
    for i in range(0, len(parts), 2):
        status, path = parts[i].decode("ascii"), parts[i + 1].decode("utf-8")
        if status not in ("A", "M", "D"):
            raise Rejected("rename or unknown change")
        result.append((status, path))
    return result


def check_report(path, base, tip, allowed_evidence):
    matched = EVIDENCE.fullmatch(path)
    if not matched:
        raise Rejected("wrong report name")
    payload = git("show", tip + ":" + path)
    if len(payload) > 16000:
        raise Rejected("oversized report")
    report = payload.decode("utf-8")
    if not report.startswith("# MegaQML Phase 2p "):
        raise Rejected("wrong report heading")
    marker = chr(96)
    match = re.search("^Source SHA: " + marker + "([0-9a-f]{40})"
                      + marker + "$", report, re.MULTILINE)
    if not match:
        raise Rejected("missing source SHA")
    source = match.group(1)
    if source[:12] != matched.group(1) or not ancestor(base, source) or (
            not ancestor(source, tip)):
        raise Rejected("unreviewed source")
    if subprocess.run(
            ["git", "-C", str(ROOT), "cat-file", "-e", source + ":" + path],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL).returncode == 0:
        raise Rejected("report already existed at source")
    for _, previous in changes(base, source):
        if not wull(previous) and previous not in allowed_evidence:
            raise Rejected("unreviewed source edit")
    lines = [s for s in report.splitlines() if s.startswith("| ")
             and not s.startswith("| Test |")]
    rows = [ROW.fullmatch(s) for s in lines]
    if (len(rows) != 40 or any(x is None for x in rows)
            or [x.group(1) for x in rows] != EXPECTED_TESTS
            or any(x.group(4) != source for x in rows)
            or any(x.group(2) == "PASS" and x.group(3) != "0" for x in rows)):
        raise Rejected("mismatched 40-case matrix")
    states = {x.group(1): x.group(2) for x in rows}
    if states["megaqml_race_repeatability"] == "PASS" and (
            "race_repeat_attempts=8" not in report or
            "race_repeat_passes=8" not in report):
        raise Rejected("missing repeatability proof")
    if not re.search("^Aggregate: (PASS|FAIL) ", report, re.MULTILINE):
        raise Rejected("missing aggregate")
    required = ("megaqml_phase2_contract", "megaqml_race_repeat_contract",
                "quickshell_ui_race", "megaqml_race_repeatability")
    if any(states[t] == "FAIL" for t in required) and (
            "Aggregate: FAIL" not in report):
        raise Rejected("misreported required failure")


def validate(base, tip):
    if not SHA.fullmatch(base) or not SHA.fullmatch(tip):
        raise Rejected("invalid commit")
    if not ancestor(base, tip):
        raise Rejected("divergent history")
    reports = []
    for status, path in changes(base, tip):
        if wull(path):
            continue
        if status != "A" or not EVIDENCE.fullmatch(path):
            raise Rejected("unreviewed changed path")
        reports.append(path)
    if len(reports) > 12:
        raise Rejected("excessive reports")
    for path in reports:
        check_report(path, base, tip, set(reports))


if __name__ == "__main__":
    try:
        if len(sys.argv) != 3:
            raise Rejected("missing args")
        validate(sys.argv[1], sys.argv[2])
    except (Rejected, OSError, UnicodeError, subprocess.CalledProcessError):
        print("UNREVIEWED_CHANGE")
        raise SystemExit(78)
    print("REVIEWED_ANCESTRY_OK")
