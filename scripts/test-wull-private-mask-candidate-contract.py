#!/usr/bin/env python3
"""INERT exact-source/private-staging contract for Wull mask A/B comparison.

No Wayland input, compositor, Rust daemon, live shell or production edit.
Only private filesystem copies and source/command structure are examined.
"""
import ast
from pathlib import Path
import runpy
import tempfile

ROOT = Path(__file__).resolve().parents[1]
GENERATOR = ROOT / "scripts/wull-private-mask-candidate.py"
PARENT = ROOT / "scripts/wull-manual-nested-pointer.py"
CHILD = ROOT / "scripts/wull-manual-pointer-child.py"

for item in (GENERATOR, PARENT, CHILD):
    ast.parse(item.read_text(encoding="utf-8"))

gen = runpy.run_path(str(GENERATOR), run_name="wull_candidate_inert_only")
child = runpy.run_path(str(CHILD), run_name="wull_candidate_inert_child")
parent = runpy.run_path(str(PARENT), run_name="wull_candidate_inert_parent")

perimeter_path = ROOT / "modules/abyss/AbyssPerimeter.qml"
body_path = ROOT / "modules/abyss/companion/AbyssCompanion.qml"
original = perimeter_path.read_text(encoding="utf-8")
body = body_path.read_text(encoding="utf-8")
marker = gen["INPUT_MARKER"]
source = gen["candidate_source"](original, body)

assert original.count(marker) == 1
assert source.count(marker) == 0
assert source.count("PRIVATE_NESTED_WULL_CANDIDATE_MASK") == 1
assert source.replace(gen["CANDIDATE"], marker) == original
assert 'root.companionEdge === "left"' in source
assert 'root.companionEdge === "right"' in source
assert '["top", "bottom", "left", "right"].includes(' in source
assert 'root.companionScale === 1' in source
assert 'verticalCandidate ? 92 : 76' in source
assert 'verticalCandidate ? 76 : 92' in source
assert 'candidateActive ? bodyBBoxWidth : 0' in source
assert 'candidateActive ? bodyBBoxHeight : 0' in source
assert 'onActivated: companionBridge.sendEvent("click")' in source

for altered in (original.replace(marker, "Region {}"), original + marker):
    try:
        gen["candidate_source"](altered, body)
    except ValueError as error:
        assert str(error) == "unreviewed_production_mask_or_multiple_regions"
    else:
        raise AssertionError("Unreviewed production mask unexpectedly accepted")
try:
    gen["candidate_source"](original, body.replace("width: 76; height: 92", "width: 75; height: 92"))
except ValueError as error:
    assert str(error) == "unreviewed_centered_top_body"
else:
    raise AssertionError("Unreviewed body geometry unexpectedly accepted")

with tempfile.TemporaryDirectory(prefix="wull-candidate-inert-") as tmp:
    folder = Path(tmp)
    shell = folder / "shell"
    shell.mkdir()
    target = gen["stage_candidate_modules"](ROOT, shell)
    assert target.parent == shell / "modules/abyss"
    assert target.is_file() and not target.is_symlink()
    assert target.read_text(encoding="utf-8") == source
    assert (shell / "modules").is_dir() and not (shell / "modules").is_symlink()
    assert (shell / "modules/abyss/companion").is_symlink()
    assert (shell / "modules/abyss/qmldir").is_symlink()
    assert perimeter_path.read_text(encoding="utf-8") == original
    try:
        gen["stage_candidate_modules"](ROOT, shell)
    except ValueError as error:
        assert str(error) == "candidate_module_shadow_already_exists"
    else:
        raise AssertionError("Existing private shadow overwritten")

    candidate_config = __import__("json").loads((ROOT / "defaults/config.json").read_text())
    candidate_config["abyss"]["companion"].update({
        "enabled": True, "interactive": True, "edge": "top", "size": 1})
    private_shell, env = child["phase_config"](
        folder / "candidate", child["PRODUCTION"], "candidate",
        candidate_config, candidate_mask=True)
    assert (private_shell / "modules/abyss/AbyssPerimeter.qml").is_file()
    assert "PRIVATE_NESTED_WULL_CANDIDATE_MASK" in (
        private_shell / "modules/abyss/AbyssPerimeter.qml").read_text()
    assert not (private_shell / "modules").is_symlink()
    assert env["QT_QPA_PLATFORM"] == "wayland"
    assert perimeter_path.read_text(encoding="utf-8") == original

assert parent["REVIEWED"]["scripts/wull-private-mask-candidate.py"] == (
    "91049b2ca2beb7b1936af624adca5133d251ea3c")
assert parent["REVIEWED"]["scripts/wull-manual-pointer-child.py"] == (
    "071f4eb257a52d2a35e8d06962ab9dfe6c90f802")
source_parent = PARENT.read_text(encoding="utf-8")
source_child = CHILD.read_text(encoding="utf-8")
for marker in (
    '--acknowledge-nested-pointer-candidate',
    '--acknowledge-nested-pointer-candidate-bottom',
    '--acknowledge-nested-pointer-candidate-right',
    '"wull-mask-right-"',
    '"wull-mask-bottom-"',
    'candidate_mode=candidate_mode',
    '"private_candidate_mask_tested"',
    '"wull-mask-candidate-"',
    '"production_mask_changed": False',
):
    assert marker in source_parent, marker
for marker in (
    'candidate_comparison_requires_absolute_native_pointer',
    'candidate_mask=candidate',
    'candidate_empty_margin_pass_through',
    'candidate_body_real_bridge_and_rust',
    'candidate_exterior_underlay_control',
    'after_baseline_unmap_exterior_underlay_control',
    'post_baseline_unmap_pointer_target_unverified',
    'nested_output_geometry_changed_before_injection',
    'baseline_to_candidate_cleanup_unproven',
    '"WULL_PRIVATE_POINTER_MODE"',
    '"candidate-mask-bottom"',
    '"candidate-mask-right"',
    'helper["all_edge_targets"]',
):
    assert marker in source_child or marker in source_parent, marker

# Source-measured four-edge bounds are supported by the prior postchange
# offscreen production receipt. This is INERT geometry, not physical clicks.
targets = runpy.run_path(
    str(ROOT / "scripts/wull-pointer-targets.py"),
    run_name="wull_all_edge_targets_inert_only")
assert parent["REVIEWED"]["scripts/wull-pointer-targets.py"] == (
    "527ebecd01e2fc51d497e0de73a0f3bcd83305ac")
all_edge = targets["all_edge_targets"]
base = targets["top_edge_targets"]
assert all_edge(1280, 720, "top") == base(1280, 720)
source_boxes = {
    "top": (112, 98, 18, 3, 76, 92),
    "bottom": (112, 98, 18, 3, 76, 92),
    "left": (98, 112, 3, 18, 92, 76),
    "right": (98, 112, 3, 18, 92, 76),
}
for edge, (hw, hh, dx, dy, bw, bh) in source_boxes.items():
    item = all_edge(1280, 720, edge)
    host = item["host_bounds"]
    mapped = item["mapped_body_bounds"]
    assert item["edge"] == edge
    assert (host[2], host[3]) == (hw, hh)
    assert mapped == (host[0] + dx, host[1] + dy, bw, bh)
    center = item["body_center"]
    margin = item["inside_host_outside_body"]
    outside = item["outside_host_control"]
    for p in (center, margin, outside):
        assert 2 <= p[0] < 1278 and 41 <= p[1] < 718
    assert mapped[0] < center[0] < mapped[0] + bw
    assert mapped[1] < center[1] < mapped[1] + bh
    if edge in ("top", "bottom"):
        assert host[0] < margin[0] < mapped[0]
        assert outside[0] < host[0] or outside[0] > host[0] + hw
    else:
        assert host[1] < margin[1] < mapped[1]
        assert outside[1] < host[1] or outside[1] > host[1] + hh
for bad in ("auto", "TOP", "", "diagonal"):
    try:
        all_edge(1280, 720, bad)
    except ValueError as error:
        assert str(error) == "unreviewed_pointer_edge"
    else:
        raise AssertionError("Unreviewed physical edge accepted")

print("WULL_PRIVATE_MASK_CANDIDATE_INERT_CONTRACT_PASS")
