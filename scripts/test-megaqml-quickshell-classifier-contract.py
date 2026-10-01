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
    ("MEGAQML_QS_UI_CAUSE_DEFAULT_PROPERTY /home/private/secret password=abc\\n"
     "MEGAQML_QS_UI_STAGE_COMPONENT", "ui-material", "ui_cause_default_property"),
    ("MEGAQML_QS_UI_CAUSE_TYPE_RESOLUTION /home/private/name",
     "ui-waffle", "ui_cause_type_resolution"),
    ("MEGAQML_QS_UI_CAUSE_MISSING_IMPORT", "ui-material", "ui_cause_missing_import"),
    ("MEGAQML_QS_UI_CAUSE_PROPERTY_ASSIGNMENT", "ui-waffle", "ui_cause_property_assignment"),
    ("MEGAQML_QS_UI_CAUSE_SINGLETON", "ui-material", "ui_cause_singleton"),
    ("MEGAQML_QS_UI_CAUSE_LOADING_TIMEOUT", "ui-waffle", "ui_cause_loading_timeout"),
    ("MEGAQML_QS_UI_CAUSE_NO_DETAIL", "ui-material", "ui_cause_no_detail"),
    ("MEGAQML_QS_UI_CAUSE_OTHER", "ui-waffle", "ui_cause_other"),
    ("MEGAQML_QS_UI_TYPE_CONTENT_PAGE /home/private/secret", "ui-material",
     "ui_type_content_page"),
    ("MEGAQML_QS_UI_TYPE_W_SETTINGS_PAGE password=secret", "ui-waffle",
     "ui_type_w_settings_page"),
    ("MEGAQML_QS_UI_TYPE_SHARED_SERVICE /home/private", "ui-material",
     "ui_type_shared_service"),
    ("MEGAQML_QS_UI_TYPE_W_INFO_BAR password=private", "ui-waffle",
     "ui_type_w_info_bar"),
    ("MEGAQML_QS_UI_TYPE_TRANSLATION", "ui-material", "ui_type_translation"),
    ("MEGAQML_QS_UI_RUNTIME_PAGE_LEASE_ABSENT /home/private/secret",
     "ui-material", "ui_runtime_page_lease_absent"),
    ("MEGAQML_QS_UI_RUNTIME_SERVICE_CONSUMERS_ZERO password=test",
     "ui-material", "ui_runtime_service_consumers_zero"),
    ("MEGAQML_QS_UI_RUNTIME_CHECKING_BUSY /home/private",
     "ui-material", "ui_runtime_checking_busy"),
    ("MEGAQML_QS_UI_RUNTIME_SERVICE_UNAVAILABLE password=private",
     "ui-material", "ui_runtime_service_unavailable"),
    ("MEGAQML_QS_UI_RUNTIME_NO_REQUEST", "ui-material", "ui_runtime_no_request"),
    ("MEGAQML_QS_UI_RUNTIME_UNEXPECTED_STATE", "ui-material", "ui_runtime_unexpected_state"),
    ("MEGAQML_QS_UI_RUNTIME_PAGE_GONE /home/private",
     "ui-material", "ui_runtime_page_gone"),
    ("MEGAQML_QS_UI_RUNTIME_PAGE_HIDDEN /home/private",
     "ui-waffle", "ui_runtime_page_hidden"),
    ("MEGAQML_QS_UI_RUNTIME_LEASE_SERVICE_MISMATCH password=secret",
     "ui-material", "ui_runtime_lease_service_mismatch"),
    ("MEGAQML_QS_UI_RUNTIME_LEASE_NOT_ACTIVATED /home/private",
     "ui-waffle", "ui_runtime_lease_not_activated"),
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
