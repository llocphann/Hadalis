#!/usr/bin/env python3
"""Synthetic checks: Quickshell classifier never publishes arbitrary local logs."""
from pathlib import Path
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
classifier = root / "scripts/test-megaqml-quickshell-classify.py"
cases = (
    ("file:///home/private/demo.qml: module Example.Private is not installed",
     "dormant", "missing_import"),
    ("MEGAQML_QS_DORMANT_INVALID sensitive-account-name",
     "dormant", "unexpected_dormant_state"),
    ("ReferenceError: password=private-marker", "dormant",
     "qml_reference_or_type_error"),
    ("MEGAQML_QS_ACTIVE_INVALID password=private-marker",
     "active-present", "unexpected_active_state"),
    ("MEGAQML_QS_ACTIVE_INVALID sensitive-account-name",
     "active-malformed", "unexpected_active_state"),
    ("PRIVATE_FAKE_STDERR_CANARY /home/private/key", "active-exit-failure", "unclassified"),
    ("MEGAQML_QS_ACTIVE_INVALID token=secret", "active-hang", "unexpected_active_state"),
    ("MEGAQML_QS_REFRESH_INVALID password=test-secret",
     "refresh-coalesce", "unexpected_refresh_state"),
    ("MEGAQML_QS_REFRESH_INVALID /home/private/secret",
     "refresh-stale-reacquire", "unexpected_refresh_state"),
    ("MEGAQML_QS_RECOVERY_INVALID token=secret",
     "recovery-exit", "unexpected_recovery_state"),
    ("MEGAQML_QS_RECOVERY_INVALID /home/private/path",
     "recovery-timeout", "unexpected_recovery_state"),
    ("MEGAQML_QS_UI_INVALID path=/home/private/material",
     "ui-material", "unexpected_ui_component_state"),
    ("MEGAQML_QS_UI_INVALID password=private-marker",
     "ui-waffle", "unexpected_ui_component_state"),
    ("MEGAQML_QS_UI_STAGE_COMPONENT /home/private/path password=test", 
     "ui-material", "ui_component_load"),
    ("MEGAQML_QS_UI_STAGE_CONSTRUCT /home/private/path", 
     "ui-waffle", "ui_component_create"),
    ("MEGAQML_QS_UI_STAGE_NAVIGATION sensitive-account-name", 
     "ui-material", "ui_navigation"),
    ("MEGAQML_QS_UI_STAGE_DETECTION password=test", 
     "ui-waffle", "ui_detection"),
    ("MEGAQML_QS_UI_STAGE_RELEASE /home/private/path", 
     "ui-material", "ui_consumer_release"),
    ("MEGAQML_QS_UI_STAGE_DEADLINE /home/private/path", 
     "ui-waffle", "ui_detection_deadline"),
    ("", "baseline", "no_diagnostic_output"),
)
with tempfile.TemporaryDirectory(prefix="megaqml-classifier-") as temp:
    output = Path(temp) / "stdout"
    error = Path(temp) / "stderr"
    for sample, mode, category in cases:
        output.write_text(sample, encoding="utf-8")
        error.write_text("", encoding="utf-8")
        completed = subprocess.run(
            [sys.executable, str(classifier), str(output), str(error), mode],
            text=True, capture_output=True, check=True)
        assert completed.stdout.strip() == f"quickshell_smoke_category={mode}:{category}"
        assert not completed.stderr
        for forbidden in ("/home/", "password", "sensitive-account-name"):
            assert forbidden not in completed.stdout
print("PASS MegaQML isolated runtime diagnostic redaction")
