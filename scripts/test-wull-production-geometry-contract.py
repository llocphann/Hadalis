#!/usr/bin/env python3
"""Inert source-safety and parser checks for postchange Wull production geometry."""
import ast
from pathlib import Path
import runpy

root = Path(__file__).resolve().parents[1]
runner = (root / "scripts/wull-manual-production-geometry.py").read_text()
qml = (root / "modules/abyss/companion/AbyssCompanion.qml").read_text()
fixture = (root / "scripts/wull-fixtures/footprint/shell.qml").read_text()
ast.parse(runner)
for marker in (
    'sys.argv[1:] != ["--qualify-production-geometry"]',
    'BASE = "5dde4e2f0559b7adac52ab0438435884236c24f9"',
    'EXPECTED_COMPANION_BLOB = "b5b01835a282458eba0d0268396ae2c350d919d2"',
    '"QT_QPA_PLATFORM": "offscreen"',
    '"production_four_edge_containment_failed"',
    '"production_mask_modified_by_test": False',
    '"physical_pointer_mask": "not_tested"',
    'git("rev-parse", target + ":modules/abyss/companion/AbyssCompanion.qml")',
):
    assert marker in runner, marker
assert "transformOrigin: Item.Center" in qml
assert "anchors.centerIn: parent" in qml
assert "transformOrigin: Item.Bottom" not in qml
assert 'root.inspect(topBody, "top")' in fixture
assert 'root.inspect(rightBody, "right")' in fixture
assert 'root.inspect(bottomBody, "bottom")' in fixture
assert 'root.inspect(leftBody, "left")' in fixture
fn = runpy.run_path(str(root / "scripts/wull-manual-production-geometry.py"),
                    run_name="wull_geometry_contract_only")["summarize"]
def box(edge, inside=True):
    return {
        "edge": edge, "valid": True, "host_width": 112, "host_height": 98,
        "body_width": 76, "body_height": 92,
        "mapped_x": 18, "mapped_y": 3,
        "mapped_width": 76, "mapped_height": 92,
        "within_host": inside,
    }
rows = fn([box(x) for x in ("right", "bottom", "top", "left")])
assert [x["edge"] for x in rows] == ["top", "right", "bottom", "left"]
assert all(x["body_stays_within_host"] and 0 < x["bbox_to_host_ratio"] < .9
           for x in rows)
assert not all(x["body_stays_within_host"] for x in
               fn([box("right", False), box("bottom"), box("top"), box("left")]))
print("WULL_PRODUCTION_GEOMETRY_CONTRACT_PASS")
