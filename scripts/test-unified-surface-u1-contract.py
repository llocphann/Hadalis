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
    U1 / "run-u1.sh",
    U1 / "README.md",
]

for path in REQUIRED_TEXT:
    assert path.is_file(), f"missing U1 file: {path.relative_to(ROOT)}"

qml = (U1 / "U1Surface.qml").read_text()
frag = (U1 / "U1Surface.frag").read_text()
build = (U1 / "build-shader.sh").read_text()
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

for network_tool in ("curl ", "wget "):
    assert network_tool not in build, "shader baker must not download at build/runtime"

exclusions = json.loads((ROOT / "sdata" / "runtime-exclusions.json").read_text())
assert "scripts/unified-surface" in exclusions["excludedPaths"], (
    "isolated U1 directory must not ship in the production runtime payload"
)

qsb = U1 / "U1Surface.qsb"
assert qsb.is_file() and qsb.stat().st_size > 0, "committed U1Surface.qsb is required"

print("unified-surface U1 static contract: PASS")
