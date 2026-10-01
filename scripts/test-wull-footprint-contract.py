#!/usr/bin/env python3
"""Inert parser and safety test for real QML four-edge Wull geometry."""
import ast
from pathlib import Path
import runpy

root = Path(__file__).resolve().parents[1]
script = (root / "scripts/wull-manual-footprint.py").read_text()
fixture = (root / "scripts/wull-fixtures/footprint/shell.qml").read_text()
ast.parse(script)
for required in (
    'sys.argv[1:] != ["--observe-footprint"]',
    '"QT_QPA_PLATFORM": "offscreen"',
    '[dbus, "--", qs, "--path", str(shell / "shell.qml")]',
    'shutil.copyfile(FIXTURE, shell / "shell.qml")',
    '"physical_pointer_mask": "not_tested"',
    '"current_production_mask": "whole_companion_host"',
    'private.mkdir(parents=True, mode=0o700, exist_ok=False)',
):
    assert required in script, required
for required in ('root.inspect(topBody, "top")',
                 'root.inspect(rightBody, "right")',
                 'root.inspect(bottomBody, "bottom")',
                 'root.inspect(leftBody, "left")',
                 'body.mapToItem(host, body.width, body.height)'):
    assert required in fixture, required
fn = runpy.run_path(str(root / "scripts/wull-manual-footprint.py"),
                    run_name="wull_footprint_test_only")["summarize"]
def row(edge, inside=True):
    return dict(edge=edge, valid=True, host_width=112, host_height=98,
                body_width=76, body_height=92, mapped_x=18,
                mapped_y=6, mapped_width=76, mapped_height=92,
                within_host=inside)
values = fn([row("left", False), row("bottom"), row("right"), row("top")])
assert [v["edge"] for v in values] == ["top", "right", "bottom", "left"]
assert values[0]["bbox_to_host_ratio"] < 1
assert not values[3]["body_stays_within_host"]
for bad in ([row("top")], [row("top")] * 4):
    try:
        fn(bad)
    except ValueError:
        pass
    else:
        raise AssertionError("missing or duplicate edges must fail closed")
print("WULL_FOOTPRINT_CONTRACT_PASS")
