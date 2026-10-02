#!/usr/bin/env python3
"""Inert pixel allowlist tests: never inspect owner file or publish to Git."""
from pathlib import Path
import runpy
import struct

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts/wull-curated-matrix-export-v3.py"
SOURCE = SCRIPT.read_text()
for required in (
    "old_output_provenance(original)",
    "inspector[\"audit\"]()",
    "inspector[\"find_private\"]()",
    "safe_pixels(*original_rgba, inspector[\"ROI\"])",
    "four reviewed RGBA rectangles only",
    "PUSH_RESULT_NEEDS_GITHUB_RECONCILIATION",
    '"GIT_TERMINAL_PROMPT": "0"',
    '"GCM_INTERACTIVE": "never"',
    '"GIT_ASKPASS": "/bin/false"',
    '"push",',
    '"HEAD:refs/heads/dev"',
    'git_options(PROFILE, push_remote)',
    'has_token(PROFILE)',
    'PUSH_REF_MOVED',
    'PUSH_AUTH_UNAVAILABLE',
):
    assert required in SOURCE, required
assert '"--publish-safe-only"' in SOURCE
assert not any(bad in SOURCE for bad in ("git reset --hard",
                                        "git push --force",
                                        "grim -o",
                                        "subprocess.Popen"))
module = runpy.run_path(str(SCRIPT), run_name="wull_curated_inert")
assert module["SOURCE"] == "3dc5f9691164fb8929ba11003fa1b61483dc561b"
assert module["OLD_JOB"] == "JOB-WULL-SMOOTH-DOME-P1E0042-20261002-16"
assert 'OLD_JOB + ":2"' in SOURCE and '"action-2.json"' in SOURCE

inspector = runpy.run_path(
    str(ROOT / "scripts/wull-existing-matrix-evidence-v3.py"),
    run_name="wull_curated_inert_inspector"
)
w = h = 512
rois = inspector["ROI"]
original = bytearray(w * h * 4)
for y in range(h):
    for x in range(w):
        p = (y * w + x) * 4
        inside = any(x0 <= x < x1 and y0 <= y < y1
                     for x0, y0, x1, y1 in rois)
        if inside:
            color = ((30, 60, 100), (78, 144, 192), (186, 205, 242))[x % 3]
            original[p:p+4] = bytes((*color, 255))
        else:
            original[p:p+4] = b"\x33\x44\x55\xff"  # synthetic out-of-policy
# Pixel RGB must be zero if alpha zero even INSIDE an approved ROI.
masked = (rois[0][1] * w + rois[0][0]) * 4
original[masked:masked + 4] = b"\x91\x92\x93\x00"
safe = module["safe_pixels"](w, h, original, rois)
width, height, decoded = inspector["rgba_verified"](safe)
assert (width, height) == (512, 512)
assert module["safe_pixels"](width, height, decoded, rois) == safe
for y in range(h):
    for x in range(w):
        at = (y * w + x) * 4
        inside = any(x0 <= x < x1 and y0 <= y < y1
                     for x0, y0, x1, y1 in rois)
        if inside and at != masked:
            assert decoded[at:at + 4] == original[at:at + 4]
        else:
            assert decoded[at:at + 4] == b"\0\0\0\0"
assert all(c["multiple_rgba_color_bands"]
           for c in inspector["mechanical_cells"](width, height, decoded))
# A curated artifact has exactly IHDR, IDAT and IEND: no inherited metadata.
types, at = [], 8
while at < len(safe):
    n = struct.unpack_from(">I", safe, at)[0]
    types.append(safe[at + 4:at + 8])
    at += 12 + n
assert types == [b"IHDR", b"IDAT", b"IEND"]
try:
    module["safe_pixels"](256, 256, original, rois)
    raise AssertionError("bad image dimensions accepted")
except module["Unsafe"] as error:
    assert str(error) == "CURATION_GEOMETRY_UNQUALIFIED"
print("WULL_CURATED_SYNTHETIC_EXPORT_FAKE_ONLY_PASS")
