#!/usr/bin/env python3
"""Fake-only behavior and path isolation for the F1 private matrix classifier."""
import importlib.util
import io
import os
from pathlib import Path
import tempfile
import contextlib

script = Path(__file__).resolve().parent / "megaqml-f1-local-matrix-classify.py"
spec = importlib.util.spec_from_file_location("matrix", script)
matrix = importlib.util.module_from_spec(spec)
spec.loader.exec_module(matrix)
sha = "1" * 40
other = "2" * 40


def fixture():
    return (
        "# MegaQML Phase 2p repeated synthetic race evidence\n"
        + "\nSource SHA: \x60" + sha + "\x60\n\n"
        + "| Test | Result | Exit code | Source SHA |\n"
        + "|---|---|---:|---|\n"
        + "".join(
            "| " + test + " | PASS | 0 | " + sha + " |\n"
            for test in matrix.EXPECTED_TESTS
        )
        + "race_repeat_attempts=8\nrace_repeat_passes=8\n"
        + "Aggregate: PASS (synthetic; no rendered desktop)\n"
    )


good = fixture()
assert matrix.classify_text(good, sha) == "report_contract_pass"
assert matrix.classify_text(good, other) == "source_mismatch"
assert matrix.classify_text(good.replace("PASS | 0", "SKIP | 127", 1), sha) == "matrix_unqualified"
assert matrix.classify_text(good.replace("PASS | 0", "FAIL | 88", 1), sha) == "matrix_unqualified"
assert matrix.classify_text(good.replace("race_repeat_passes=8", "race_repeat_passes=7"), sha) == "race_unqualified"
assert matrix.classify_text(good.replace("race_repeat_attempts=8\n", ""), sha) == "race_unqualified"
assert matrix.classify_text(good + "race_repeat_passes=8\n", sha) == "race_unqualified"
assert matrix.classify_text(good.replace("Aggregate: PASS", "Aggregate: FAIL"), sha) == "aggregate_unqualified"
assert matrix.classify_text(good.replace("Aggregate: PASS", "Aggregate: PASS\nAggregate: PASS"), sha) == "aggregate_unqualified"
assert matrix.classify_text(good.replace("Source SHA:", "Missing SHA:", 1), sha) == "source_mismatch"
assert matrix.classify_text(good.replace(matrix.EXPECTED_TESTS[1], matrix.EXPECTED_TESTS[0], 1), sha) == "matrix_unqualified"
assert matrix.classify_text(good.replace("| Test |", "| Untrusted |"), sha) == "matrix_unqualified"
assert matrix.classify_text(good.replace("# MegaQML Phase 2p", "# Untrusted"), sha) == "wrong_report_type"

with tempfile.TemporaryDirectory() as folder:
    root = Path(folder)
    scope = root / "docs/evidence/megaqml"
    scope.mkdir(parents=True)
    file = scope / ("phase2p-" + sha[:12] + "-20261003T010203Z.md")
    file.write_text(good)
    rel = file.relative_to(root)
    assert matrix.classify_path(str(rel), sha, root) == "report_contract_pass"
    assert matrix.classify_path(str(rel), other, root) == "source_mismatch"
    assert matrix.classify_path(str(rel), "garbage", root) == "invalid_pin"
    private = root / "private"
    private.write_text("sensitive fixture names and paths")
    file.unlink()
    file.symlink_to(private)
    assert matrix.classify_path(str(rel), sha, root) == "path_out_of_scope"
    file.unlink()
    file.write_text("a" * (matrix.MAX_REPORT_BYTES + 1))
    assert matrix.classify_path(str(rel), sha, root) == "report_unavailable"
    file.unlink()
    file.write_bytes(b"\xff\xfe")
    assert matrix.classify_path(str(rel), sha, root) == "report_unavailable"
    file.unlink()
    file.write_text(good)
    assert matrix.classify_path("../outside", sha, root) == "report_unavailable"
    assert matrix.classify_path(str(private), sha, root) == "path_out_of_scope"

print("PASS F1 private 40-case report classifier fake-only contract")
