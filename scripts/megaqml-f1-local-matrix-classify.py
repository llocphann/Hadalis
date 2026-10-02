#!/usr/bin/env python3
"""Private, offline F1 40-row synthetic report contract classifier.

No MEGAcmd access, no git write, no raw output, no source provenance claim.
"""
import argparse
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
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
SHA = re.compile(r"[0-9a-f]{40}\Z")
NAME = re.compile(r"phase2p-([0-9a-f]{12})-(20[0-9]{6}T[0-9]{6}Z)\.md\Z")
ROW = re.compile(
    r"\| ([a-z][a-z0-9_]*) \| (PASS|FAIL|SKIP) \| "
    r"([0-9]{1,3}) \| ([0-9a-f]{40}) \|\Z"
)
MAX_REPORT_BYTES = 32768


def classify_text(report, pin):
    """Finite categories only; never return text from private report."""
    if not report.startswith("# MegaQML Phase 2p "):
        return "wrong_report_type"
    sources = re.findall(r"^Source SHA: \x60([0-9a-f]{40})\x60$", report, re.M)
    if sources != [pin]:
        return "source_mismatch"
    rows = [
        line for line in report.splitlines()
        if line.startswith("| ") and not line.startswith("| Test |")
    ]
    matched = [ROW.fullmatch(line) for line in rows]
    if len(matched) != 40 or any(row is None for row in matched):
        return "matrix_unqualified"
    if [row.group(1) for row in matched] != EXPECTED_TESTS:
        return "matrix_unqualified"
    if any(row.group(2) != "PASS" or row.group(3) != "0"
           or row.group(4) != pin for row in matched):
        return "matrix_unqualified"
    aggregate = re.findall(r"^Aggregate: ([^\r\n]+)$", report, re.M)
    if len(aggregate) != 1 or not aggregate[0].startswith("PASS ("):
        return "aggregate_unqualified"
    attempts = re.findall(r"^race_repeat_attempts=([^\r\n]+)$", report, re.M)
    passes = re.findall(r"^race_repeat_passes=([^\r\n]+)$", report, re.M)
    if attempts != ["8"] or passes != ["8"]:
        return "race_unqualified"
    return "report_contract_pass"


def classify_path(report_arg, pin, root=ROOT):
    if SHA.fullmatch(pin) is None:
        return "invalid_pin"
    try:
        root = root.resolve(strict=True)
        scope = (root / "docs/evidence/megaqml").resolve(strict=True)
        if not scope.is_relative_to(root):
            return "path_out_of_scope"
        requested = Path(report_arg)
        if not requested.is_absolute():
            requested = root / requested
        if requested.is_symlink():
            return "path_out_of_scope"
        report = requested.resolve(strict=True)
        filename = NAME.fullmatch(report.name)
        if report.parent != scope or filename is None:
            return "path_out_of_scope"
        if filename.group(1) != pin[:12]:
            return "source_mismatch"
        if not report.is_file():
            return "report_unavailable"
        if report.stat().st_size > MAX_REPORT_BYTES:
            return "report_unavailable"
        text = report.read_text(encoding="utf-8")
        if len(text.encode("utf-8")) > MAX_REPORT_BYTES:
            return "report_unavailable"
        return classify_text(text, pin)
    except (OSError, RuntimeError, ValueError, UnicodeError):
        return "report_unavailable"


def main():
    parser = argparse.ArgumentParser(description="Offline private F1 report only")
    parser.add_argument("--report", required=True)
    parser.add_argument("--expect-sha", required=True)
    args = parser.parse_args()
    result = classify_path(args.report, args.expect_sha)
    print("MEGAQML_F1_LOCAL_MATRIX_CLASSIFIER")
    print("REASON=" + result)
    print("REPORT_CONTRACT_PASS=" + str(result == "report_contract_pass").upper())
    print("TEST_EXECUTION_PROVEN=NO")
    print("DESKTOP_VISUAL_ACCEPTED=NO")
    print("VENDOR_OR_ACCOUNT_USED=NO")
    return 0 if result == "report_contract_pass" else 21


if __name__ == "__main__":
    raise SystemExit(main())
