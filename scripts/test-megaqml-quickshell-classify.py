#!/usr/bin/env python3
"""Allowlist diagnostic categories for local isolated Quickshell; never emit logs."""
from pathlib import Path
import sys

if len(sys.argv) != 4 or sys.argv[3] not in ("baseline", "dormant", "active-present", "active-missing",
                                                     "active-wrong-id", "active-unsafe-secret",
                                                     "active-malformed", "active-exit-failure", "active-hang",
                                                     "refresh-coalesce", "refresh-stale-reacquire",
                                                     "recovery-exit", "recovery-timeout",
                                                     "ui-material", "ui-waffle", "ui-shared"):
    raise SystemExit(64)
raw = "\n".join(Path(p).read_text(encoding="utf-8", errors="replace")[:16384]
                for p in sys.argv[1:3]).lower()
# Never publish the local QML engine's error text, paths or arbitrary data.
# Fixed stage tokens are emitted by the reviewed fixture only.
# More specific fixed cause tokens precede the broad UI component stage.
# Never echo Qt's original error string or local file paths.
# Shared-page lifecycle labels are emitted only by the reviewed isolated
# fixture. Never publish raw Qt errors, temporary paths or private data.
shared_stages = (
    ("preflight", "shared_preflight"),
    ("load", "shared_load"),
    ("create", "shared_create"),
    ("navigation", "shared_navigation"),
    ("register", "shared_register"),
    ("first_result", "shared_first_result"),
    ("hide_one", "shared_hide_one"),
    ("second_start", "shared_second_start"),
    ("second_result", "shared_second_result"),
    ("final_release", "shared_final_release"),
    ("reacquire", "shared_reacquire"),
    ("third_result", "shared_third_result"),
    ("timeout", "shared_timeout"),
)
matched_shared_stage = next((category for token, category in shared_stages
                             if "megaqml_qs_shared_stage_" + token in raw), None)
ui_runtime = (
    ("page_gone", "ui_runtime_page_gone"),
    ("page_hidden", "ui_runtime_page_hidden"),
    ("lease_service_mismatch", "ui_runtime_lease_service_mismatch"),
    ("lease_not_activated", "ui_runtime_lease_not_activated"),
    ("page_lease_absent", "ui_runtime_page_lease_absent"),
    ("service_consumers_zero", "ui_runtime_service_consumers_zero"),
    ("service_consumers_multiple", "ui_runtime_service_consumers_multiple"),
    ("no_request", "ui_runtime_no_request"),
    ("extra_request", "ui_runtime_extra_request"),
    ("service_unavailable", "ui_runtime_service_unavailable"),
    ("checking_busy", "ui_runtime_checking_busy"),
    ("checking_idle", "ui_runtime_checking_idle"),
    ("service_not_checked", "ui_runtime_service_not_checked"),
    ("service_stale", "ui_runtime_service_stale"),
    ("detected_but_busy", "ui_runtime_detected_but_busy"),
    ("unexpected_state", "ui_runtime_unexpected_state"),
)
matched_ui_runtime = next((category for token, category in ui_runtime
                           if "megaqml_qs_ui_runtime_" + token in raw), None)
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
if matched_shared_stage is not None:
    kind = matched_shared_stage
elif "megaqml_qs_shared_invalid" in raw:
    kind = "unexpected_shared_state"
elif matched_ui_runtime is not None:
    kind = matched_ui_runtime
elif matched_ui_type is not None:
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
                                  "megaqml_qs_ui_shared_ok",
                                  "megaqml_qs_dormant_ok",
                                  "megaqml_qs_baseline_ok")):
    kind = "sentinel_seen_nonzero_exit"
elif not raw.strip():
    kind = "no_diagnostic_output"
else:
    kind = "unclassified"
print(f"quickshell_smoke_category={sys.argv[3]}:{kind}")
