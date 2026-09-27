#!/usr/bin/env python3
"""Exercise Material preference migration and idempotence in the production policy."""
from pathlib import Path
import subprocess
root = Path(__file__).resolve().parents[1]
subprocess.run(["node", "-e", (root / "modules/common/PanelFamilyPolicy.js").read_text() + r"""
const assert = require('node:assert/strict');
const ids = Object.keys(materialPanelMap);
for (const family of ['ii','waffle','abyss']) {
  for (let seed=0;seed<32;seed++) {
    const enabled = ids.filter((id,i) => ((seed >> (i%5)) & 1) !== 0).concat(['iiCheatsheet','wBar']);
    const input = {panelFamily:family, enabledPanels:enabled, knownPanels:ids.concat(materialSharedPanels),
      visitedPanelFamilies:[family], dock:{iconSize:43}, bar:{vertical:true}, custom:{keep:'yes'}};
    const original = JSON.stringify(input);
    const changes = migrateMaterial(input);
    assert.equal(JSON.stringify(input),original,'migration must not mutate input');
    assert.equal(changes.panelStyleVersion,1);
    assert(changes.enabledPanels.includes('abyssPerimeter'));
    assert(changes.enabledPanels.includes('wBar'));
    assert(changes.enabledPanels.includes('iiCheatsheet'));
    for (const target of new Set(Object.values(materialPanelMap))) {
      const expected = ids.some(id => materialPanelMap[id]===target && enabled.includes(id));
      assert.equal(changes.enabledPanels.includes(target),expected, family+' '+target);
      assert(changes.knownPanels.includes(target),'disabled preferences must be remembered');
    }
    const migrated = Object.assign({},input,changes);
    assert.deepEqual(migrateMaterial(migrated),{},'migration must be idempotent');
    assert.deepEqual(migrated.dock,input.dock);assert.deepEqual(migrated.custom,input.custom);
    const ensured = ensure('abyss',abyssPanels,migrated.enabledPanels,migrated.knownPanels,migrated.visitedPanelFamilies);
    for (const target of Object.values(materialPanelMap))
      assert.equal(ensured.enabled.includes(target),changes.enabledPanels.includes(target),'first visit must not revive disabled Material panels');
  }
}
const existing = migrateMaterial({panelFamily:'abyss',enabledPanels:['iiDock'],knownPanels:['iiDock','abyssDock'],visitedPanelFamilies:['abyss']});
assert(!existing.enabledPanels.includes('abyssDock'),'existing disabled Abyss preference wins');
assert.deepEqual(migrateMaterial({panelFamily:'ii',panelStyleVersion:1}),{panelFamily:'abyss'});
assert.deepEqual(migrateMaterial({panelFamily:'abyss',panelStyleVersion:1}),{});
assert.equal(migrateMaterial({}).panelFamily,'abyss');
"""], check=True)
print("PASS: Material migrates to Abyss, preserves disabled panels, Waffle and shared settings, and is idempotent")
