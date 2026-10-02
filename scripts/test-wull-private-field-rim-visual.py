#!/usr/bin/env python3
"""FAKE ONLY: reviewed real-Niri runner cloned without any safety relaxation.

Strict complete-source reversible diff vs PREVIOUS owner-qualified real
Niri screenshot coordinator. No compositor, Qt, Git writes or private images.
"""
import ast
import hashlib
from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]
PREVIOUS = ROOT / "scripts/wull-manual-private-nested-quarter-visual.py"
CURRENT = ROOT / "scripts/wull-manual-private-field-rim-visual.py"
HELPER = ROOT / "scripts/wull-private-field-rim-attachment.py"
EXPECTED = {
    PREVIOUS: "b719f2b0a6c6e0121f9f2c0467f8d4e7a28cfa9f",
    CURRENT: "61e1da5c6811bfb70c1d442efaad4ef11962eb34",
    HELPER: "b7c2ac861ab11073540d113df86a1339c7f43e6e",
}

def sha(raw):
    return hashlib.sha1(
        b"blob " + str(len(raw)).encode("ascii") + b"\0" + raw
    ).hexdigest()

for path, expected in EXPECTED.items():
    assert path.is_file() and sha(path.read_bytes()) == expected
    ast.parse(path.read_text(encoding="utf-8"))

current = CURRENT.read_text(encoding="utf-8")
prior = PREVIOUS.read_text(encoding="utf-8")
reverse = (
    (
        '"""Owner-opt-in REAL nested Niri original Wull m025 attachment comparison.\n\n'
        'Both cases have the same ORIGINAL BOTTOM×1.5 Wull and PRIVATE cradle .25.\n'
        'Only PRIVATE perimeter host anchor changes from fixed physical thickness\n'
        'to locally evaluated real Abyss shader-field inner surface boundary.',
        '"""Owner-opt-in REAL nested Niri original AbyssBar visual A/B, no host capture.\n\n'
        'First screenshot is full original BOTTOM×1.5 Wull, second is same original\n'
        'scene with only the PRIVATE cradle bottomMargin=0.25 in a mirrored QML tree.'
    ),
    (
        'SHADOW = "scripts/wull-private-field-rim-attachment.py"\n'
        'SHADOW_BLOB = "b7c2ac861ab11073540d113df86a1339c7f43e6e"\n'
        'PRIOR_VISUAL = "scripts/wull-manual-private-nested-quarter-visual.py"\n'
        'PRIOR_VISUAL_BLOB = "b719f2b0a6c6e0121f9f2c0467f8d4e7a28cfa9f"\n'
        'LAYOUT = "modules/abyss/looks/AbyssLayout.js"\n'
        'LAYOUT_BLOB = "f65d9c1922696d236fc0d3bfee735ad8df16924b"\n'
        'FIELD = "modules/abyss/looks/AbyssField.frag"\n'
        'FIELD_BLOB = "75af27a7220d364b2eb1700bb7b29cc19c8ae2bd"\n'
        'STYLE = "modules/abyss/looks/AbyssStyle.qml"\n'
        'STYLE_BLOB = "4cc05dbaf547a3eff366647cb388abe8c31af5d5"\n'
        'FIELD_QML = "modules/abyss/looks/AbyssField.qml"\n'
        'FIELD_QML_BLOB = "6b9588b1233748991f1dfeaa886879d51c7c0530"\n'
        'FIELD_QSB = "modules/abyss/looks/AbyssField.frag.qsb"\n'
        'FIELD_QSB_BLOB = "fe36c75ceb1bab6d4676e87512ee549b8d100f45"\n'
        'BAR = "modules/abyss/bar/AbyssBar.qml"\n'
        'BAR_BLOB = "b9d91627734d0cfdf3057d598f7ec600649be45c"\n'
        'SURFACE = "modules/abyss/AbyssSurfaceController.qml"\n'
        'SURFACE_BLOB = "1fbbe81d2c9f62827c2e6835600caec01e24227f"',
        'SHADOW = "scripts/wull-private-panel-quarter-shadow.py"\n'
        'SHADOW_BLOB = "dd62b2b834e86d41856730547bca8ea4d73aaca8"'
    ),
    (
        '    (BORROW, BORROW_BLOB), (SHADOW, SHADOW_BLOB),\n'
        '    (PRIOR_VISUAL, PRIOR_VISUAL_BLOB), (LAYOUT, LAYOUT_BLOB),\n'
        '    (FIELD, FIELD_BLOB), (STYLE, STYLE_BLOB),\n'
        '    (FIELD_QML, FIELD_QML_BLOB), (FIELD_QSB, FIELD_QSB_BLOB),\n'
        '    (BAR, BAR_BLOB), (SURFACE, SURFACE_BLOB),\n'
        '    (PREFLIGHT, PREFLIGHT_BLOB),',
        '    (BORROW, BORROW_BLOB), (SHADOW, SHADOW_BLOB),\n'
        '    (PREFLIGHT, PREFLIGHT_BLOB),'
    ),
    (
        '--acknowledge-owned-nested-field-rim-visual',
        '--acknowledge-owned-nested-quarter-visual'
    ),
    (
        'for mode in ("screen_boundary_m025", "inner_field_rim_m025"):',
        'for mode in ("original_m0", "private_bottom_m025"):'
    ),
    (
        '    print("ORIGINAL_REAL_ABYSSBAR_AND_WULL=SOURCE_PINNED")\n'
        '    print("BOTH_CASES_ORIGINAL_CRADLE_M025=YES")\n'
        '    print("ANCHOR_COMPARISON=SCREEN_FIXED_VS_LOCAL_ABYSS_FIELD")',
        '    print("ORIGINAL_REAL_ABYSSBAR_AND_WULL=SOURCE_PINNED")\n'
        '    print("PRIVATE_M025_CHANGE=ORIGINAL_CRADLE_ONLY")'
    ),
    (
        '    print("SAME_INSTANT_PIXEL_COMPARISON=NOT_TESTED")\n'
        '    print("DYNAMIC_WAVE_ATTACHMENT=NOT_TESTED")\n'
        '    print("FOUR_EDGE_ATTACHMENT=NOT_TESTED")',
        '    print("SAME_INSTANT_PIXEL_COMPARISON=NOT_TESTED")'
    ),
    (
        'GATE=NESTED_PRIVATE_FIELD_RIM_CAPTURES_READY',
        'GATE=NESTED_PRIVATE_VISUAL_CAPTURES_READY'
    ),
)
for now, before in reverse:
    assert current.count(now) == 1, now[:45]
    current = current.replace(now, before, 1)
assert current == prior, "New Niri runner changed outside narrow reviewed A/B substitutions"
scope = runpy.run_path(str(CURRENT), run_name="inert_nested_field_source_only")
assert scope["PRIOR_VISUAL_BLOB"] == EXPECTED[PREVIOUS]
assert scope["SHADOW_BLOB"] == EXPECTED[HELPER]
assert set(scope["REQUIRED"]) >= {
    (scope["SHADOW"], EXPECTED[HELPER]),
    (scope["PRIOR_VISUAL"], EXPECTED[PREVIOUS]),
}
assert "anchor geometry" not in scope["ORIGIN"].lower()
cfg = scope["fixed_config"]("synthetic-output")
assert cfg["abyss"]["companion"]["size"] == 1.5
assert cfg["abyss"]["companion"]["edge"] == "bottom"
assert cfg["abyss"]["companion"]["interactive"] is False
assert cfg["bar"]["bottom"] is True
print("WULL_PRIVATE_FIELD_RIM_NESTED_RUNNER_INERT_PASS")
