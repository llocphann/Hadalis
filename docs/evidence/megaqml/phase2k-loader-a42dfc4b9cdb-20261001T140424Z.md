# MegaQML Phase 2k isolated loader-focused triage

Source SHA: a42dfc4b9cdb9da5c066868f9959da591cb4a221

Scope: exact reviewed Material/Waffle Cloud Storage page bodies with isolated visual stubs, copied Cloud Storage service/parser and Python-only fake static dispatcher. No real MEGAcmd, credentials, full Hadalis UI or live feature acceptance.

| Test | Result | Exit code | Source SHA |
|---|---|---:|---|
| megaqml_phase2_contract | PASS | 0 | a42dfc4b9cdb9da5c066868f9959da591cb4a221 |
| megaqml_ui_fixture_contract | PASS | 0 | a42dfc4b9cdb9da5c066868f9959da591cb4a221 |
| megaqml_diagnostic_redaction | PASS | 0 | a42dfc4b9cdb9da5c066868f9959da591cb4a221 |
| quickshell_baseline | PASS | 0 | a42dfc4b9cdb9da5c066868f9959da591cb4a221 |
| quickshell_ui_material | FAIL | 88 | a42dfc4b9cdb9da5c066868f9959da591cb4a221 |
| quickshell_ui_waffle | FAIL | 88 | a42dfc4b9cdb9da5c066868f9959da591cb4a221 |
quickshell_smoke_category=ui-material:ui_detection_deadline
quickshell_smoke_category=ui-waffle:ui_type_w_info_bar
Aggregate: FAIL (source/fixture or UI loader checks failed).
