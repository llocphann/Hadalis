#!/usr/bin/env python3
"""Allowlist diagnostic categories for local isolated Quickshell; never emit logs."""
from pathlib import Path
import sys

if len(sys.argv) != 4 or sys.argv[3] not in ("baseline", "dormant", "active-present", "active-missing",
                                                     "active-wrong-id", "active-unsafe-secret",
                                                     "active-malformed", "active-exit-failure", "active-hang"):
    raise SystemExit(64)
raw = "\n".join(Path(p).read_text(encoding="utf-8", errors="replace")[:16384]
                for p in sys.argv[1:3]).lower()
if "megaqml_qs_active_invalid" in raw:
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
                                  "megaqml_qs_dormant_ok",
                                  "megaqml_qs_baseline_ok")):
    kind = "sentinel_seen_nonzero_exit"
elif not raw.strip():
    kind = "no_diagnostic_output"
else:
    kind = "unclassified"
print(f"quickshell_smoke_category={sys.argv[3]}:{kind}")
