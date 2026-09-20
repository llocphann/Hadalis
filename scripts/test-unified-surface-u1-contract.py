#!/usr/bin/env python3
"""Static architecture guard for the isolated unified-surface U1 PoC."""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
U1 = ROOT / "scripts" / "unified-surface"

REQUIRED_TEXT = [
    U1 / "shell.qml",
    U1 / "U1Shell.qml",
    U1 / "U1Surface.qml",
    U1 / "U1Surface.frag",
    U1 / "build-shader.sh",
    U1 / "verify-shader-package.sh",
    U1 / "smoke-headless-sway.py",
    U1 / "validate-live-niri.py",
    U1 / "run-u1.sh",
    U1 / "README.md",
]

for path in REQUIRED_TEXT:
    assert path.is_file(), f"missing U1 file: {path.relative_to(ROOT)}"

shell = (U1 / "U1Shell.qml").read_text()
qml = (U1 / "U1Surface.qml").read_text()
frag = (U1 / "U1Surface.frag").read_text()
build = (U1 / "build-shader.sh").read_text()
verify = (U1 / "verify-shader-package.sh").read_text()
smoke = (U1 / "smoke-headless-sway.py").read_text()
live = (U1 / "validate-live-niri.py").read_text()
combined = qml + "\n" + frag

for forbidden in (
    "joinTop",
    "joinBottom",
    "joinLeft",
    "joinRight",
    "contactInset",
    "contactPlane",
    "ConnectedSurfaceJoinFlares",
):
    assert forbidden not in combined, f"rejected contact-patch token returned: {forbidden}"

# The renderer must remain source/module agnostic.
frag_lower = frag.lower()
for module_name in ("battery", "clock", "weather", "media", "resources"):
    assert module_name not in frag_lower, f"shader contains module-specific branch/data: {module_name}"

for required in (
    "sdRoundedRect",
    "sdRoundedRect4",
    "cornerFillFactor",
    "popupCornerRadii",
    "circularSmin",
    "circularSmaxSharpA",
    "frameSink",
    "fwidth",
    "effectRect",
    "frameOuter",
    "frameInner",
    "popupRect",
):
    assert required in frag, f"missing U1 shader invariant: {required}"

assert "visible: true" in qml, "U1 layer-shell host must remain mapped"
assert "ExclusionMode.Ignore" in qml
assert "mask: Region { item: emptyInput }" in qml
assert 'renderMode !== "control"' in qml
assert 'renderMode === "full"' in qml
assert "boundedEffectRect" in qml
assert "Math.floor(value * dpr) / dpr" in qml
assert "Math.ceil(value * dpr) / dpr" in qml
assert "FrameAnimation" in qml
assert "HADALIS_U1_BENCHMARK" in qml
assert "HADALIS_U1_SOURCE_T" in qml
assert "HADALIS_U1_ATTACHMENT_DEPTH" not in qml
assert "attachmentDepth" not in qml
assert "const restingY = innerTop" in qml
assert "const restingX = innerLeft" in qml
assert "const restingX = innerRight - pw" in qml
assert "HADALIS_U1_GEOMETRY" in qml
assert "HADALIS_U1_TRACE_GEOMETRY" in qml
assert "reveal: reveal" in qml
assert "HADALIS_U1_FULLSCREEN_PROBE" in shell
assert "Hadalis U1 Fullscreen Probe" in shell

for network_tool in ("curl ", "wget "):
    assert network_tool not in build, "shader baker must not download at build/runtime"
    assert network_tool not in verify, "shader verifier must not download at build/runtime"
    assert network_tool not in smoke, "headless smoke must not download at runtime"
    assert network_tool not in live, "live Niri validator must not download at runtime"

for extracted in ("reflect", "spirv,100", "glsl,300es", "glsl,330"):
    assert extracted in verify, f"semantic QSB verifier missing extraction: {extracted}"

for smoke_invariant in (
    'WLR_BACKENDS="headless"',
    'WLR_RENDERER="pixman"',
    'QT_QUICK_BACKEND="software"',
    'scale 1.25',
    'HADALIS_U1_MODE="control"',
    "quickshell_alive",
):
    assert smoke_invariant in smoke, f"headless smoke lost invariant: {smoke_invariant}"

exclusions = json.loads((ROOT / "sdata" / "runtime-exclusions.json").read_text())
assert "scripts/unified-surface" in exclusions["excludedPaths"], (
    "isolated U1 directory must not ship in the production runtime payload"
)

qsb = U1 / "U1Surface.qsb"
assert qsb.is_file() and qsb.stat().st_size > 0, "committed U1Surface.qsb is required"

for live_invariant in (
    'dbus_session([niri, "-c", str(config_path)]',
    '"msg", "output"',
    '"scale"',
    '"bounded"',
    '"full"',
    "component_sizes",
    "crop_iou",
    "HADALIS_U1_SOURCE_T",
    "HADALIS_U1_GEOMETRY",
    "WAYLAND_DEBUG",
    "get_layer_surface",
    "layer_surface_creation_count",
    "run_motion_lifecycle_case",
    "run_reveal_lifecycle_case",
    "run_fullscreen_lifecycle_case",
    "fullscreen-window",
    "HADALIS_U1_FULLSCREEN_PROBE",
):
    assert live_invariant in live, f"live Niri validator lost invariant: {live_invariant}"

print("unified-surface U1 static contract: PASS")
