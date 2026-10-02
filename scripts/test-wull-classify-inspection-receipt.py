#!/usr/bin/env python3
"""Pure classifier tests. No private receipts read, no Qt, no Git writes."""
from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]
m = runpy.run_path(str(ROOT / "scripts/wull-classify-inspection-receipt.py"),
                   run_name="fake_only_classifier")
func = m["classify_private"]


def example(line):
    return (
        'Traceback (most recent call last):\n'
        f'  File "/opaque/hidden/scripts/test-wull-existing-matrix-evidence.py", line {line}, in <module>\n'
        '    [REDACTED]\n'
        'AssertionError: [REDACTED]\n'
    )


for line, category in ((16, 31), (29, 32), (62, 33),
                       (69, 34), (72, 35), (78, 36), (83, 37)):
    assert func(example(line)) == category, (line, category)
assert func("error /home/owner/.config/private/token=abc") == 37
assert func(example(62) * 500) == 37
assert func(example(35).replace("test-wull-existing-matrix-evidence.py",
                                "different-fake-test.py")) == 37
assert func(example(72).replace("/opaque/hidden/scripts/", "")) == 35
# Distinct bounded exact-line diagnostic without disclosing stack or message.
detail = m["detail_private"]
assert detail(example(62)) == 111  # positive test line62 / AssertionError
assert detail(example(63).replace("AssertionError:", "TypeError:")) == 123
assert detail(example(65).replace("AssertionError:", "ValueError:")) == 142
assert detail(example(76)) == 39  # outside the independently proven stage
assert detail("untrusted private diagnostic path") == 39

reason = m["fixed_reason_private"]
assert reason(example(62).replace("AssertionError: [REDACTED]",
                                  "wull_rgba_private_inspection.InvalidCapture: PNG_DECOMPRESSED_SIZE_INVALID")) == 139
assert reason(example(62).replace("AssertionError: [REDACTED]",
                                  "wull_fake_only_inspection.Unqualified: RGBA_UNQUALIFIED")) == 142
assert reason(example(62).replace("AssertionError: [REDACTED]",
                                  "untrusted.module.Exception: FREEFORM_SECRET")) == 199
assert reason(example(76)) == 199
print("WULL_OLD_FAKE_FAILURE_CLASSIFIER_INERT_PASS")
