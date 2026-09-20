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



# Lock both profiles. Diagnostic deliberately enlarges the corner; the
# upstream-relative profile follows iRiS v2.31 defaults closely.
for token in (
    'HADALIS_IRIS_POC_PROFILE',
    'value === "upstream-relative" ? value : "diagnostic"',
    'root.upstreamRelative ? 42 : 56',
    'root.upstreamRelative ? 360 : 380',
    'root.upstreamRelative ? 30 : 48',
    'root.upstreamRelative ? 3 : 4',
    'root.upstreamRelative ? 30 : 56',
):
    assert token in window, f"profile morphology drifted: {token}"

assert 'String(raw).trim().length === 0' in window, (
    "empty environment variables must not collapse profile defaults to zero"
)


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


def shoulder_extensions(owner_h, popup_w, popup_h, popup_r, weld, fuse, depths):
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

    extensions = []
    for depth in depths:
        y = owner_h + depth
        x = popup_x - max(80.0, 2.0 * fuse)
        while x <= popup_x + 1.0:
            if field_distance(x, y) <= 0.0:
                extensions.append(popup_x - x)
                break
            x += 0.05
        else:
            raise AssertionError(f"no joined field at depth {depth}")
    return extensions


diagnostic_depths = (1, 4, 8, 16, 24, 48, 56)
diagnostic = shoulder_extensions(56, 380, 300, 48, 4, 56, diagnostic_depths)
assert 24.0 <= diagnostic[0] <= 40.0, diagnostic
for previous, current in zip(diagnostic, diagnostic[1:]):
    assert current <= previous + 0.15, diagnostic
assert 8.0 <= diagnostic[2] <= 16.0, diagnostic
assert diagnostic[-1] <= 0.6, diagnostic

upstream_depths = (1, 4, 8, 16, 24, 30)
upstream = shoulder_extensions(42, 360, 300, 30, 3, 30, upstream_depths)
assert 9.0 <= upstream[0] <= 16.0, upstream
for previous, current in zip(upstream, upstream[1:]):
    assert current <= previous + 0.15, upstream
assert 0.8 <= upstream[2] <= 3.0, upstream
assert upstream[-1] <= 0.6, upstream



# The live visual matrix must cover every edge and both clamp extremes without
# touching/restarting the production shell.
for token in (
    "for edge in top bottom left right",
    "for source_t in 0.02 0.50 0.98",
    "HADALIS_IRIS_POC_MODE",
    "HADALIS_IRIS_POC_PROFILE",
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
