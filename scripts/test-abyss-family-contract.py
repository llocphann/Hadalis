#!/usr/bin/env python3
"""Exercise the actual family policy, including disabled-panel persistence."""
from pathlib import Path
import json
import subprocess

root = Path(__file__).resolve().parents[1]
policy = (root / "modules/common/PanelFamilyPolicy.js").read_text()
program = policy + r"""
const assert = require('node:assert/strict');
assert.equal(normalize('garbage'), 'ii');
assert.equal(normalize('abyss'), 'abyss');
let family = 'ii';
for (let i = 0; i < 60; i++) {
    family = next(family);
    assert.equal(family, ['waffle', 'abyss', 'ii'][i % 3]);
}
assert.equal(new Set(abyssPanels).size, abyssPanels.length);
let result = ensure('abyss', abyssPanels, ['iiLock'], ['iiCheatsheet'], ['ii']);
assert(result.enabled.includes('abyssPerimeter'));
assert(!result.enabled.includes('iiCheatsheet')); // shared disabled preference
result.enabled = result.enabled.filter(id => id !== 'abyssDock');
result = ensure('abyss', abyssPanels, result.enabled, result.known, result.visited);
assert(!result.enabled.includes('abyssDock')); // survives repeat family visit
result = ensure('abyss', abyssPanels.concat(['abyssNew']), result.enabled, result.known, result.visited);
assert(result.enabled.includes('abyssNew')); // update migration
"""
subprocess.run(["node", "-e", program], check=True)
shell = (root / "shell.qml").read_text()
for name in ("ii", "waffle", "abyss"):
    assert f'{name}CriticalHostLoader' in shell
    assert f'{name}DeferredHostLoader' in shell
assert 'root.activePanelFamily === "ii"' in shell
assert 'root.activePanelFamily === "abyss"' in shell
assert json.loads((root / "defaults/config.json").read_text())["panelFamily"] == "ii"
for file in (root / "modules/abyss").rglob("*.qml"):
    assert 'target: "panelFamily"' not in file.read_text()
transition = (root / "modules/abyss/AbyssFamilyTransition.qml").read_text()
assert 'mask: Region {}' in transition
assert 'WlrKeyboardFocus.None' in transition
assert 'repeat: false' in transition
print("ok - three-family cycle, migration, isolation and input-free transition")
