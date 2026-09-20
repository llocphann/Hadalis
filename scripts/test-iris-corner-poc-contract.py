#!/usr/bin/env python3
"""Static guard for the developer-only iRiS-faithful corner PoC."""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]
POC = ROOT / "scripts" / "iris-corner-poc"

field = (POC / "IrisField.frag").read_text(encoding="utf-8")
wrapper = (POC / "IrisCornerField.qml").read_text(encoding="utf-8")
window = (POC / "IrisCornerPocWindow.qml").read_text(encoding="utf-8")
readme = (POC / "README.md").read_text(encoding="utf-8")
exclusions = json.loads((ROOT / "sdata" / "runtime-exclusions.json").read_text(encoding="utf-8"))

assert "scripts/iris-corner-poc" in exclusions["excludedPaths"]
assert "9574fa424c0d1008e927454e933a7fbe292f9fb2" in wrapper
assert "9574fa424c0d1008e927454e933a7fbe292f9fb2" in readme
assert (POC / "IrisField.frag.qsb").stat().st_size == 16765

for token in (
    "float roundedBox(",
    "float smoothUnion(",
    "return mix(b, a, h) - k * h * (1.0 - h);",
    "united = min(united, smoothUnion(other, bodies[i], k));",
):
    assert token in field, f"upstream iRiS field primitive missing: {token}"

for token in (
    'id: "owner"',
    'id: "popup"',
    'joins: "owner"',
    'root.geometryMode !== "edge-reach"',
    "Math.min(root.popupWidth, root.popupHeight) / 2 + 1",
    "root.ownerThickness - root.weld",
    "root.fuse",
):
    assert token in window, f"PoC geometry contract missing: {token}"

for forbidden in (
    "cornerFill",
    "borderSink",
    "contactInset",
    "contactPlane",
    "ConnectedSurfaceJoinFlares",
    "RoundCorner",
    "modules/waffle",
):
    assert forbidden not in wrapper + window, f"rejected geometry leaked into PoC: {forbidden}"

print("iRiS corner PoC contract: PASS")
