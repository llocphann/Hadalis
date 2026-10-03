#!/usr/bin/env python3
"""Execute the real Wull host decision policy across output and input states."""
from pathlib import Path
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
policy = (ROOT / "modules/abyss/companion/WullHostPolicy.js").read_text(
    encoding="utf-8"
)
perimeter = (ROOT / "modules/abyss/AbyssPerimeter.qml").read_text()
calls = re.findall(r"Region \{ item: (WullHostPolicy\.acceptsInput\([^)]*\)) \? companion : emptyInput \}", perimeter)
assert len(calls) == 1, "one complete-host Region; no new input owner"
script = policy + "\nconst productionInput = " + json.dumps(calls[0]) + ";\n" + r"""
const assert = require('node:assert/strict');
let cases = 0;
const check = (condition, label) => {
    assert(condition, label);
    cases++;
};
// Enumerate the same host predicates consumed by the real PanelWindow.
const outputs = ['DP-1', 'HDMI-A-1'];
const bool = [false, true];
for (const session of bool)
for (const ready of bool)
for (const presented of bool)
for (const fieldReady of bool)
for (const target of outputs)
for (const current of outputs) {
    const active = hostActive(
        session, ready, target, current, presented, fieldReady
    );
    const expected = session && ready && presented && fieldReady
        && target === current;
    check(active === expected, 'exact output-owned readiness gate');
    for (const interactive of bool)
    for (const visible of bool) {
        check(acceptsInput(active, interactive, visible)
            === (expected && interactive && visible),
            'input cannot outlive the active host');
    }
}
for (const invalid of ['', null, undefined, 17]) {
    check(!hostActive(true, true, invalid, 'DP-1', true, true),
        'no ambiguous output owner');
}
// Evaluate the actual Region expression across emergence/relocation readiness,
// rather than insisting that its old one-line spelling remain unchanged.
const WullHostPolicy = {acceptsInput};
for (const active of bool)
for (const interactive of bool)
for (const visible of bool)
for (const inputReady of bool) {
    const window = {companionHostActive: active};
    const companion = {interactive, visible, inputReady};
    check(eval(productionInput) === (active && interactive && visible && inputReady),
        'partially emerged or relocating Wull cannot capture input');
}
check(!acceptsInput(false, true, true), 'unexpected exit releases input');
check(!hostActive(true, false, 'DP-1', 'DP-1', true, true),
      'unexpected daemon exit hides host');
check(!hostActive(true, true, 'DP-1', 'DP-2', true, true),
      'non-target output has no companion');
for (const scale of [0.65, 1, 1.5, 2]) {
    for (const extent of [0, 1, 80, 130, 320, 720, 1080, 1920, 3840]) {
        for (const along of [-4, 0, 0.08, 0.5, 0.72, 0.92, 1, 17, NaN]) {
            const result = alongPosition(extent, 112 * scale, along);
            check(Number.isFinite(result) && result >= 0
                && result <= extent, 'bounded even for tiny logical output');
            if (extent > 0)
                check(Math.abs(alongPosition(extent, 112 * scale, .5)
                    - extent * .5) < 1e-8, 'symmetric center');
        }
    }
}
check(alongPosition(1920, 112, .72) === 1920 * .72,
      'ordinary placement unchanged');
check(alongPosition(80, 168, .92) === 40,
      'narrow vertical viewport uses its center');
console.log('WULL_HOST_POLICY_PASS ' + cases);
"""
subprocess.run(["node", "-e", script], cwd=ROOT, check=True)
