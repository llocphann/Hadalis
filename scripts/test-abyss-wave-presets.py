#!/usr/bin/env python3
"""Named Waves presets stay restrained while existing Custom values survive."""
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
program = (ROOT / "modules/abyss/looks/AbyssWave.js").read_text() + r'''
const assert=require('node:assert/strict');
const oldCalm={amplitude:.12,propagation:.35,speed:.3,decay:.85,tension:.8,viscosity:.85,rebound:.2,corner:.4};
const oldCustom={amplitude:.8,propagation:.8,speed:.55,decay:.55,tension:.5,viscosity:.55,rebound:.6,corner:.8};
assert.deepEqual(presets.balanced,oldCalm,'Balanced is the previous Calm');
for (const key of Object.keys(oldCustom)) assert.equal(parameters({preset:'custom'})[key],oldCustom[key]);
for (const key of Object.keys(oldCustom)) {
 const options={preset:'custom',[key]:.17};
 assert.equal(parameters(options)[key],.17,'explicit Custom values remain authoritative');
}
for (const [index,name] of ['calm','balanced','fluid','deep'].entries()) {
 const p=parameters({preset:name}),state=create(256,1920,1200,p);
 assert(p.amplitude<=.65 && p.rebound<=.45 && p.viscosity>=.65,'restrained motion envelope');
 if(index) assert(p.amplitude>presets[['calm','balanced','fluid','deep'][index-1]].amplitude);
 assert(heightLimit(state)<=25,'named presets have a modest height cap');
}
assert.deepEqual(parameters({preset:'unknown'}),parameters({preset:'balanced'}));
console.log('PASS: restrained named presets, previous Calm as Balanced and unchanged Custom controls');
'''
subprocess.run(["node", "-e", program], check=True)
