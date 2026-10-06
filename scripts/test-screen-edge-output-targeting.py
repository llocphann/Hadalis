#!/usr/bin/env python3
"""Behavior/read-order oracle for Screen Edge output targeting compaction."""

from pathlib import Path
import random

ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / "modules/screenCorners/ScreenEdges.qml").read_text(encoding="utf-8")

start = SOURCE.index("    function targetsOutput(outputName, configuredList) {")
end = SOURCE.index("\n    function iiBarTargetsOutput(", start)
block = SOURCE[start:end]

for token in (
    "for (const screen of Quickshell.screens)",
    "const screenName = String(screen?.name ?? \"\")",
    "if (screenName.length > 0 && list.includes(screenName))",
    "hasConfiguredOutput = true",
    "if (!hasConfiguredOutput)",
    "return list.includes(outputName)",
):
    assert token in block, token

assert "Quickshell.screens.filter" not in block
assert ".filter(" not in block
assert "break" not in block
# A return inside the scan would change dependency/read order. The only returns
# before/after the loop are the original guards/final answer.
loop = block[
    block.index("for (const screen of Quickshell.screens)"):
    block.index("if (!hasConfiguredOutput)")
]
assert "return " not in loop


def js_string(value):
    # Test inputs mirror the actual screen-name domain plus nullish values.
    if value is None:
        return ""
    return str(value)


def old_impl(output_name, configured, screens):
    trace = []
    if len(output_name) == 0:
        return False, trace
    items = [] if configured is None else list(configured)
    if len(items) == 0:
        return True, trace

    matched = []
    for idx, raw_name in enumerate(screens):
        trace.append(idx)
        name = js_string(raw_name)
        if len(name) > 0 and name in items:
            matched.append(raw_name)

    if len(matched) == 0:
        return True, trace
    return output_name in items, trace


def new_impl(output_name, configured, screens):
    trace = []
    if len(output_name) == 0:
        return False, trace
    items = [] if configured is None else list(configured)
    if len(items) == 0:
        return True, trace

    has_configured_output = False
    for idx, raw_name in enumerate(screens):
        trace.append(idx)
        name = js_string(raw_name)
        if len(name) > 0 and name in items:
            has_configured_output = True

    if not has_configured_output:
        return True, trace
    return output_name in items, trace


rng = random.Random(0x53454447)
names = ["", "DP-1", "DP-2", "HDMI-A-1", "eDP-1", None]
for _ in range(50000):
    screens = [rng.choice(names) for _ in range(rng.randrange(0, 9))]
    configured = None if rng.randrange(8) == 0 else [
        rng.choice(["DP-1", "DP-2", "HDMI-A-1", "eDP-1", "stale"])
        for _ in range(rng.randrange(0, 7))
    ]
    output = rng.choice(["", "DP-1", "DP-2", "HDMI-A-1", "eDP-1", "other"])

    old = old_impl(output, configured, screens)
    new = new_impl(output, configured, screens)
    assert old == new, (output, configured, screens, old, new)

print("SCREEN_EDGE_OUTPUT_TARGETING_PARITY_PASS cases=50000")
