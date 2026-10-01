#!/usr/bin/env python3
"""Allowlist diagnostic categories for local isolated Quickshell; never emit logs."""
from pathlib import Path
import sys

if len(sys.argv) != 4 or sys.argv[3] not in ("baseline", "dormant", "active-present", "active-missing",
                                                     "active-wrong-id", "active-unsafe-secret",
                                                     "active-malformed", "active-exit-failure", "active-hang",
                                                     "refresh-coalesce", "refresh-stale-reacquire",
                                                     "recovery-exit", "recovery-timeout",
                                                     "ui-material", "ui-waffle"):
    raise SystemExit(64)
raw = "\n".join(Path(p).read_text(encoding="utf-8", errors="replace")[:16384]
                for p in sys.argv[1:3]).lower()
# Never publish the local QML engine's error text, paths or arbitrary data.
# Fixed stage tokens are emitted by the reviewed fixture only.
# More specific fixed cause tokens precede the broad UI component stage.
# Never echo Qt's original error string or local file paths.
ui_types = (
    ("content_page", "ui_type_content_page"),
    ("task_navigator", "ui_type_task_navigator"),
    ("card_section", "ui_type_card_section"),
    ("settings_group", "ui_type_settings_group"),
    ("styled_combo", "ui_type_styled_combo"),
    ("settings_note", "ui_type_settings_note"),
    ("styled_text", "ui_type_styled_text"),
    ("ripple_button", "ui_type_ripple_button"),
    ("w_settings_page", "ui_type_w_settings_page"),
    ("w_settings_card", "ui_type_w_settings_card"),
    ("w_settings_dropdown", "ui_type_w_settings_dropdown"),
    ("w_info_bar", "ui_type_w_info_bar"),
    ("w_settings_button", "ui_type_w_settings_button"),
    ("shared_service", "ui_type_shared_service"),
    ("translation", "ui_type_translation"),
    ("appearance", "ui_type_appearance"),
)
matched_ui_type = next((category for token, category in ui_types
                        if "megaqml_qs_ui_type_" + token in raw), None)
ui_causes = (
    ("default_property", "ui_cause_default_property"),
    ("type_resolution", "ui_cause_type_resolution"),
    ("missing_import", "ui_cause_missing_import"),
    ("property_assignment", "ui_cause_property_assignment"),
    ("singleton", "ui_cause_singleton"),
    ("syntax", "ui_cause_syntax"),
    ("loading_timeout", "ui_cause_loading_timeout"),
    ("no_error_api", "ui_cause_no_error_api"),
    ("no_detail", "ui_cause_no_detail"),
    ("absent", "ui_cause_component_absent"),
    ("other", "ui_cause_other"),
)
matched_ui_cause = next((category for token, category in ui_causes
                         if "megaqml_qs_ui_cause_" + token in raw), None)
ui_stages = (
    ("scenario", "ui_invalid_scenario"),
    ("preflight", "ui_preflight"),
    ("component", "ui_component_load"),
    ("construct", "ui_component_create"),
    ("navigation", "ui_navigation"),
    ("detection", "ui_detection"),
    ("release", "ui_consumer_release"),
    ("deadline", "ui_detection_deadline"),
)
matched_ui_stage = next((category for token, category in ui_stages
                         if "megaqml_qs_ui_stage_" + token in raw), None)
if matched_ui_type is not None:
    kind = matched_ui_type
elif matched_ui_cause is not None:
    kind = matched_ui_cause
elif matched_ui_stage is not None:
    kind = matched_ui_stage
elif "megaqml_qs_ui_invalid" in raw:
    kind = "unexpected_ui_component_state"
elif "megaqml_qs_recovery_invalid" in raw:
    kind = "unexpected_recovery_state"
elif "megaqml_qs_refresh_invalid" in raw:
    kind = "unexpected_refresh_state"
elif "megaqml_qs_active_invalid" in raw:
    kind = "unexpected_active_state"
elif "megaqml_qs_dormant_invalid" in raw:
    kind = "unexpected_dormant_state"
elif "no module named" in raw or "module " in raw and "is not installed" in raw:
    kind = "missing_import"
elif "is not a type" in raw or "type " in raw and " unavailable" in raw:
    kind = "qml_type_resolution"
elif "referenceerror" in raw or "typeerror" in raw:
    kind = "qml_reference_or_type_error"
elif "syntax error" in raw or "unexpected token" in raw:
    kind = "qml_syntax"
elif "permission denied" in raw:
    kind = "environment_permission"
elif "failed to create" in raw or "could not" in raw and "platform" in raw:
    kind = "headless_platform"
elif any(token in raw for token in ("megaqml_qs_active_present_ok",
                                  "megaqml_qs_active_missing_ok",
                                  "megaqml_qs_rejected_ok",
                                  "megaqml_qs_exit_failure_ok",
                                  "megaqml_qs_timeout_ok",
                                  "megaqml_qs_coalesced_ok",
                                  "megaqml_qs_reacquire_ok",
                                  "megaqml_qs_exit_recovery_ok",
                                  "megaqml_qs_timeout_recovery_ok",
                                  "megaqml_qs_ui_material_ok",
                                  "megaqml_qs_ui_waffle_ok",
                                  "megaqml_qs_dormant_ok",
                                  "megaqml_qs_baseline_ok")):
    kind = "sentinel_seen_nonzero_exit"
elif not raw.strip():
    kind = "no_diagnostic_output"
else:
    kind = "unclassified"
print(f"quickshell_smoke_category={sys.argv[3]}:{kind}")
