#!/usr/bin/env python3
"""Static guard for the developer-only iRiS-faithful corner PoC."""
from pathlib import Path
import json
import math

ROOT = Path(__file__).resolve().parents[1]
POC = ROOT / "scripts" / "iris-corner-poc"

field = (POC / "IrisField.frag").read_text(encoding="utf-8")
wrapper = (POC / "IrisCornerField.qml").read_text(encoding="utf-8")
window = (POC / "IrisCornerPocWindow.qml").read_text(encoding="utf-8")
readme = (POC / "README.md").read_text(encoding="utf-8")
capture = (POC / "capture-matrix.sh").read_text(encoding="utf-8")
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



# Lock the deliberately enlarged default card-owner morphology. This is the
# settled iRiS card analogue: a small weld overlap plus explicit smooth union,
# not the edge-piece reach rule.
for token in (
    'HADALIS_IRIS_POC_OWNER_THICKNESS", 56',
    'HADALIS_IRIS_POC_POPUP_WIDTH", 380',
    'HADALIS_IRIS_POC_POPUP_HEIGHT", 300',
    'HADALIS_IRIS_POC_POPUP_RADIUS", 48',
    'HADALIS_IRIS_POC_WELD", 4',
    'HADALIS_IRIS_POC_FUSE", 56',
):
    assert token in window, f"default morphology drifted: {token}"


def rounded_box(x, y, cx, cy, half_w, half_h, radius):
    radius = min(radius, half_w, half_h)
    qx = abs(x - cx) - (half_w - radius)
    qy = abs(y - cy) - (half_h - radius)
    return (
        math.hypot(max(qx, 0.0), max(qy, 0.0))
        + min(max(qx, qy), 0.0)
        - radius
    )


def smooth_union(a, b, k):
    h = max(0.0, min(1.0, 0.5 + 0.5 * (b - a) / k))
    return b * (1.0 - h) + a * h - k * h * (1.0 - h)


screen_w = 900.0
owner_h = 56.0
popup_w = 380.0
popup_h = 300.0
popup_r = 48.0
weld = 4.0
fuse = 56.0
popup_x = (screen_w - popup_w) / 2.0
popup_y = owner_h - weld


def field_distance(x, y):
    owner = rounded_box(
        x, y,
        screen_w / 2.0, owner_h / 2.0,
        screen_w / 2.0 + 2.0 * fuse, owner_h / 2.0,
        0.0,
    )
    popup = rounded_box(
        x, y,
        popup_x + popup_w / 2.0, popup_y + popup_h / 2.0,
        popup_w / 2.0, popup_h / 2.0,
        popup_r,
    )
    return min(owner, popup, smooth_union(owner, popup, fuse))


def left_shoulder_extension(depth):
    y = owner_h + depth
    x = popup_x - 80.0
    while x <= popup_x + 1.0:
        if field_distance(x, y) <= 0.0:
            return popup_x - x
        x += 0.05
    raise AssertionError(f"no joined field at depth {depth}")


depths = (1, 4, 8, 16, 24, 48, 56)
extensions = [left_shoulder_extension(depth) for depth in depths]

# The join must start visibly outside the popup at the seam, taper inward
# monotonically, then converge to the popup side. A second blob underneath the
# popup would violate this single-contour taper.
assert 24.0 <= extensions[0] <= 40.0, extensions
for previous, current in zip(extensions, extensions[1:]):
    assert current <= previous + 0.15, extensions
assert 8.0 <= extensions[2] <= 16.0, extensions
assert extensions[-1] <= 0.6, extensions



# The live visual matrix must cover every edge and both clamp extremes without
# touching/restarting the production shell.
for token in (
    "for edge in top bottom left right",
    "for source_t in 0.02 0.50 0.98",
    "HADALIS_IRIS_POC_MODE",
    "HADALIS_IRIS_POC",
    "grim",
    "manifest.tsv",
    "contact-sheet-",
):
    assert token in capture, f"live matrix harness missing: {token}"

for forbidden in (
    "inir restart",
    "inir reload",
    "ipc call",
    "modules/waffle",
):
    assert forbidden not in capture, f"live matrix may affect production: {forbidden}"

print("iRiS corner PoC contract: PASS")
