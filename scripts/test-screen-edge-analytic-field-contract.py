#!/usr/bin/env python3
"""Production contract for the Screen Edge analytic single-pass field."""

from __future__ import annotations

import math
from pathlib import Path
import random
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / "modules/screenCorners"
frag_path = BASE / "ScreenEdgeField.frag"
qml_path = BASE / "ScreenEdgeField.qml"
qsb_path = BASE / "ScreenEdgeField.frag.qsb"

frag = frag_path.read_text(encoding="utf-8")
qml = qml_path.read_text(encoding="utf-8")
runtime = (BASE / "ScreenEdges.qml").read_text(encoding="utf-8")

for token in (
    "float roundedBox(",
    "bool axisDeep =",
    "bool centralCore =",
    "if (axisDeep && centralCore)",
    "fragColor = vec4(0.0);",
    "float d = roundedBox(",
    "float frameCover = smoothstep(-aa, aa, d);",
    "float innerShadow = smoothstep(-reach, 0.0, d)",
    "if (u.shadowColor.a > 0.0)",
    "float sharpReach = max(aa, reach / 15.0);",
    "float midReach = max(sharpReach, reach / 3.0);",
    "0.175 * smoothstep(-sharpReach, 0.0, d)",
    "0.250 * smoothstep(-midReach, 0.0, d)",
    "0.075 * smoothstep(-reach, 0.0, d)",
    "vec3 frameRgb = u.frameColor.rgb * frameCover;",
    "vec3 shadowRgb = u.shadowColor.rgb * innerShadow;",
    "float shadowAlpha = u.shadowColor.a * innerShadow;",
    "fragColor = u.frameColor * u.qt_Opacity;",
):
    assert token in frag, token

# The candidate's performance boundary is intentionally strict: no texture
# inputs/captures and no general-purpose blur path.
for forbidden in (
    "sampler2D",
    "texture(",
    "textureLod(",
    "imageLoad(",
    "u.frameColor.rgb * frameAlpha",
    "u.shadowColor.rgb * shadowAlpha",
):
    assert forbidden not in frag, forbidden

for token in (
    "ShaderEffect {",
    'fragmentShader: Qt.resolvedUrl("ScreenEdgeField.frag.qsb")',
    "required property real leftInset",
    "required property real topInset",
    "required property real rightInset",
    "required property real bottomInset",
    "readonly property vector4d insets:",
    "readonly property vector4d params:",
):
    assert token in qml, token
for forbidden in ("ShaderEffectSource", "MultiEffect", "ShapePath", "PathArc"):
    assert forbidden not in qml, forbidden

assert qsb_path.is_file() and qsb_path.stat().st_size > 1000, (
    "Packaged ScreenEdgeField QSB is missing"
)

# Production ownership: the analytic field is the normal painter. The former
# Shape/MultiEffect renderer is only constructed on ShaderEffect.Error.
for token in (
    "ScreenEdgeField {",
    "id: frameField",
    "leftInset: frameWindow.frameLeftInset",
    "topInset: frameWindow.frameTopInset",
    "rightInset: frameWindow.frameRightInset",
    "bottomInset: frameWindow.frameBottomInset",
    "radius: root.rounding",
    "elevationEnabled: frameWindow.physicalShadowActive",
    "id: legacyFramePainter",
    "active: frameField.status === ShaderEffect.Error",
    "sourceComponent: Component {",
):
    assert token in runtime, token
assert runtime.index("ScreenEdgeField {") < runtime.index("id: legacyFramePainter")
fallback = runtime[runtime.index("id: legacyFramePainter"):]
assert "MultiEffect {" in fallback
assert "ShapePath {" in fallback


def sd_round_box(
    x: float,
    y: float,
    width: float,
    height: float,
    left: float,
    top: float,
    right: float,
    bottom: float,
    radius: float,
) -> float:
    lo_x, lo_y = max(left, 0.0), max(top, 0.0)
    hi_x = max(lo_x, width - max(right, 0.0))
    hi_y = max(lo_y, height - max(bottom, 0.0))
    hx = max((hi_x - lo_x) * 0.5, 0.0)
    hy = max((hi_y - lo_y) * 0.5, 0.0)
    cx, cy = (lo_x + hi_x) * 0.5, (lo_y + hi_y) * 0.5
    r = min(max(radius, 0.0), hx, hy)
    qx = abs(x - cx) - (hx - r)
    qy = abs(y - cy) - (hy - r)
    return math.hypot(max(qx, 0.0), max(qy, 0.0)) + min(max(qx, qy), 0.0) - r


def reference_inside(
    x: float,
    y: float,
    width: float,
    height: float,
    left: float,
    top: float,
    right: float,
    bottom: float,
    radius: float,
) -> bool:
    l, t = max(left, 0.0), max(top, 0.0)
    rgt = max(l, width - max(right, 0.0))
    bot = max(t, height - max(bottom, 0.0))
    rad = min(max(radius, 0.0), (rgt - l) * 0.5, (bot - t) * 0.5)
    if not (l <= x <= rgt and t <= y <= bot):
        return False
    if l + rad <= x <= rgt - rad or t + rad <= y <= bot - rad:
        return True
    cx = l + rad if x < l + rad else rgt - rad
    cy = t + rad if y < t + rad else bot - rad
    return (x - cx) ** 2 + (y - cy) ** 2 <= rad ** 2


rng = random.Random(0x53435245454E)
for _ in range(50000):
    width = rng.uniform(320.0, 7680.0)
    height = rng.uniform(240.0, 2160.0)
    left, top, right, bottom = [rng.uniform(1.0, 96.0) for _ in range(4)]
    radius = rng.uniform(0.0, 96.0)
    x = rng.uniform(-4.0, width + 4.0)
    y = rng.uniform(-4.0, height + 4.0)
    d = sd_round_box(x, y, width, height, left, top, right, bottom, radius)
    inside = reference_inside(
        x, y, width, height, left, top, right, bottom, radius
    )

    # Mirror the production deep-interior guard and prove it can only reject
    # pixels whose exact SDF is already beyond the complete shadow/AA band.
    l, t = max(left, 0.0), max(top, 0.0)
    rgt = max(l, width - max(right, 0.0))
    bot = max(t, height - max(bottom, 0.0))
    hx = max((rgt - l) * 0.5, 0.0)
    hy = max((bot - t) * 0.5, 0.0)
    clamped_radius = min(max(radius, 0.0), hx, hy)
    shadow_reach = rng.uniform(0.0, 32.0)
    safe_reach = max(shadow_reach, 2.0)
    axis_deep = (
        x >= l + safe_reach
        and x <= rgt - safe_reach
        and y >= t + safe_reach
        and y <= bot - safe_reach
    )
    central_core = (
        (x >= l + clamped_radius and x <= rgt - clamped_radius)
        or (y >= t + clamped_radius and y <= bot - clamped_radius)
    )
    if axis_deep and central_core:
        assert d <= -safe_reach + 1e-7, (
            "deep-interior guard rejected a potentially visible fragment"
        )
    # Ignore an infinitesimal mathematical boundary where either sign is an
    # equivalent coverage convention; everywhere else classification is exact.
    if abs(d) > 1e-7:
        assert (d < 0.0) == inside

compiler = shutil.which("qsb") or "/usr/lib/qt6/bin/qsb"
if Path(compiler).is_file():
    with tempfile.TemporaryDirectory(prefix="hadalis-screen-edge-qsb-") as tmp:
        rebuilt = Path(tmp) / qsb_path.name
        subprocess.run(
            [compiler, "--qt6", "-o", str(rebuilt), str(frag_path)],
            check=True,
            capture_output=True,
            text=True,
        )
        assert rebuilt.read_bytes() == qsb_path.read_bytes(), (
            "ScreenEdgeField QSB differs from GLSL source"
        )

print("SCREEN_EDGE_ANALYTIC_FIELD_CONTRACT_PASS")
