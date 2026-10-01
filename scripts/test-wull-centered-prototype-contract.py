#!/usr/bin/env python3
"""Inert safety/parser checks for the four-edge centered Wull prototype."""
import ast
from pathlib import Path
import runpy

root = Path(__file__).resolve().parents[1]
code = (root / "scripts/wull-manual-centered-prototype.py").read_text()
qml = (root / "scripts/wull-fixtures/centered-prototype/shell.qml").read_text()
ast.parse(code)
for token in (
    'sys.argv[1:] != ["--observe-centered-prototype"]',
    '"QT_QPA_PLATFORM": "offscreen"',
    '"production_mask_modified": False',
    '"production_layout": "not_modified"',
    '"candidate_pointer_interaction": "not_tested"',
    '"candidate_still_clips_or_captures_full_host"',
    'row["body_stays_within_host"]',
    'row["bbox_to_host_ratio"] < 0.9',
):
    assert token in code, token
for token in (
    "body.anchors.bottom = undefined",
    "body.anchors.horizontalCenter = undefined",
    "body.anchors.centerIn = host",
    "body.transformOrigin = Item.Center",
    'root.inspect(topBody, "top")',
    'root.inspect(rightBody, "right")',
    'root.inspect(bottomBody, "bottom")',
    'root.inspect(leftBody, "left")',
    "WULL_CENTERED_PROTOTYPE_GEOMETRY",
):
    assert token in qml, token
assert qml.count("AbyssCompanion {") == 4
assert "WaterDropletBody {" not in qml
summarize = runpy.run_path(
    str(root / "scripts/wull-manual-centered-prototype.py"),
    run_name="centered_test_only"
)["summarize"]
def item(edge, inside=True):
    return dict(
        edge=edge, valid=True, host_width=98, host_height=112,
        body_width=76, body_height=92, mapped_x=3, mapped_y=18,
        mapped_width=92, mapped_height=76, within_host=inside
    )
good = summarize([item(x) for x in ("left", "bottom", "right", "top")])
assert [x["edge"] for x in good] == ["top", "right", "bottom", "left"]
assert all(x["body_stays_within_host"] and x["bbox_to_host_ratio"] < .9
           for x in good)
bad = summarize([item("left", False), item("bottom"),
                 item("right"), item("top")])
assert not all(x["body_stays_within_host"] for x in bad)
print("WULL_CENTERED_PROTOTYPE_CONTRACT_PASS")
