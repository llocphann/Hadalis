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

# Execute the real settings applicability function rather than mirroring it.
registry = (root / "modules/settings/SettingsPageRegistry.qml").read_text()
applicability = registry.split("function isPageApplicable(index: int): bool {", 1)[1].split("\n    }", 1)[0]
subprocess.run(["node", "-e", """
const assert = require('node:assert/strict');
const root = {pages: Array(30), barPageIndex: 2, abyssFamily: false, waffleFamily: false,
    isHiddenLegacyIndex: i => [18,19,21,27,28].includes(i)};
function applicable(index) {""" + applicability + """}
for (const family of ['ii','waffle','abyss']) {
    root.abyssFamily = family === 'abyss'; root.waffleFamily = family === 'waffle';
    assert(applicable(1)); assert(applicable(10)); // shared System/Modules routes
    assert(!applicable(-1)); assert(!applicable(30)); assert(!applicable(18));
    assert.equal(applicable(2), family === 'ii');
    assert.equal(applicable(11), family === 'waffle');
    assert.equal(applicable(16), family === 'ii');
    assert.equal(applicable(29), family === 'ii');
}
"""], check=True)

# Exercise the production output-selection expression with hotplug/stale names.
selector = (root / "modules/abyss/settings/AbyssOutputSelector.qml").read_text()
effective = selector.split("readonly property var effective: ", 1)[1].split("\n", 1)[0]
subprocess.run(["node", "-e", """
const assert = require('node:assert/strict');
function resolve(selected, connected) { return """ + effective + """; }
assert.deepEqual(resolve([], ['A','B']), ['A','B']);
assert.deepEqual(resolve(['gone'], ['A','B']), ['A','B']);
assert.deepEqual(resolve(['B','gone'], ['A','B']), ['B']);
assert.deepEqual(resolve(['B'], ['A']), ['A']);
assert.deepEqual(resolve([], []), []);
"""], check=True)
shell = (root / "shell.qml").read_text()
for name in ("ii", "waffle", "abyss"):
    assert f'{name}CriticalHostLoader' in shell
    assert f'{name}DeferredHostLoader' in shell
assert 'root.activePanelFamily === "ii"' in shell
assert 'root.activePanelFamily === "abyss"' in shell
assert json.loads((root / "defaults/config.json").read_text())["panelFamily"] == "ii"
for file in (root / "modules/abyss").rglob("*.qml"):
    assert 'target: "panelFamily"' not in file.read_text()
for target in ("osd", "osdVolume", "osdInput"):
    assert shell.count(f'target: "{target}"') == 1
    for family_dir in ("abyss", "waffle", "onScreenDisplay"):
        for file in (root / "modules" / family_dir).rglob("*.qml"):
            assert f'target: "{target}"' not in file.read_text(), file
transition = (root / "modules/abyss/AbyssFamilyTransition.qml").read_text()
assert 'mask: Region {}' in transition
assert 'WlrKeyboardFocus.None' in transition
assert 'repeat: false' in transition
print("ok - family cycle/migration/isolation, shared IPC, settings routes and output selection")
