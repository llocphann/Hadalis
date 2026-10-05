#!/usr/bin/env python3
"""Parity contract for CustomThemeEditor quick-adjustment key selection."""
from itertools import product
from pathlib import Path

SOURCE = Path("modules/settings/CustomThemeEditor.qml").read_text(encoding="utf-8")


def before(snapshot):
    keys = [
        key for key in snapshot.keys()
        if key.startswith("m3")
        and isinstance(snapshot[key], str)
        and snapshot[key].startswith("#")
    ]
    return [(key, snapshot[key]) for key in keys]


def after(snapshot):
    selected = []
    for key in snapshot.keys():
        if not key.startswith("m3"):
            continue
        original = snapshot[key]
        if not isinstance(original, str) or not original.startswith("#"):
            continue
        selected.append((key, original))
    return selected


samples = [
    ("m3Primary", "#112233"),
    ("m3Secondary", "rgb(1,2,3)"),
    ("m3Number", 42),
    ("otherColor", "#abcdef"),
    ("m3Empty", ""),
    ("m3Accent", "#fedcba"),
]
cases = 0
for size in range(1, len(samples) + 1):
    for mask in product((False, True), repeat=size):
        snapshot = {}
        for index in range(size):
            key, value = samples[index]
            snapshot[key] = value if mask[index] else None
        assert before(snapshot) == after(snapshot), (snapshot, before(snapshot), after(snapshot))
        cases += 1

assert 'const colorKeys = Object.keys(originalColors)' in SOURCE
assert 'Object.keys(originalColors).filter(' not in SOURCE
assert 'const original = originalColors[key]' in SOURCE
assert 'if (!key.startsWith("m3"))' in SOURCE
assert 'typeof original !== "string" || !original.startsWith("#")' in SOURCE
assert 'let c = Qt.color(original)' in SOURCE

for token in (
    'c.hslSaturation * satFactor',
    'c.hslLightness + brightDelta',
    'const targetHue = tempDelta > 0 ? 0.08 : 0.58',
    'const shiftAmount = Math.abs(tempDelta) * 0.15',
    'Qt.hsla(newHue, newSat, newLight, c.a)',
    'updates[`appearance.customTheme.${key}`] = newColor.toString()',
):
    assert token in SOURCE, token

publish = SOURCE.index('Config.setNestedValues(updates)')
apply = SOURCE.index('applyToShell()', publish)
assert publish < apply

print(f"ok - CustomTheme quick-adjustment key parity across {cases} cases")
