#!/usr/bin/env python3
"""Qualify the actual finite wave solver, including corners and sleep."""
from pathlib import Path
import subprocess
root = Path(__file__).resolve().parents[1]
program = (root / "modules/abyss/looks/AbyssWave.js").read_text() + r"""
const assert=require('node:assert/strict');
const p=parameters({preset:'balanced'});
assert.equal(arc('top',100,1920,1200),100);
assert.equal(arc('right',100,1920,1200),2020);
assert.equal(arc('bottom',100,1920,1200),4940);
assert.equal(arc('left',100,1920,1200),6140);
let s=create(256,1920,1200,p);
assert.equal(s.mode,'SLEEPING');assert.equal(advance(s,.016),false);
impulse(s,'top',40,70,1,1);
assert.equal(s.mode,'ACTIVE');
let crossed=false,rebound=false,spread=false;
for(let i=0;i<1600;i++) {
    advance(s,1/120);
    crossed ||= s.displacement[255]>.05;
    spread ||= Math.abs(s.displacement[12])>.02;
    rebound ||= s.displacement.some(v=>v<-.03);
    assert(s.displacement.every(Number.isFinite));
}
assert(crossed,'corner wrap transmits to left edge');
assert(spread,'neighbor coupling moves energy beyond the impulse');
assert(rebound,'physical restoring spring reverses displacement');
assert.equal(s.mode,'SLEEPING');assert(s.displacement.every(v=>v===0));
const steps=s.steps;advance(s,.05);assert.equal(s.steps,steps,'sleep does no integration');
impulse(s,'bottom',900,400,-1,4);assert(s.velocity.some(v=>v<0),'close reverses the impulse');
for(const preset of Object.keys(presets)) for(const [w,h] of [[1920,1200],[480,320]]) {
    s=create(256,w,h,parameters({preset}));
    setMass(s,[{edge:'top',along:20,span:w*.7,mass:4,progress:1}]);
    assert(Math.max(...s.mass)>3);
    for(let i=0;i<10;i++) impulse(s,'top',w*.5,w*.4,1,4);
    for(let i=0;i<2400;i++) {
        advance(s,1/120);
        assert(s.displacement.every(v=>Number.isFinite(v)&&Math.abs(v)<=36+.001));
        assert(s.velocity.every(Number.isFinite));
    }
    assert.equal(s.mode,'SLEEPING',preset+' eventually sleeps under heavy mass');
}
const custom=parameters({preset:'custom',amplitude:9,decay:-1});
assert.equal(custom.amplitude,1);assert.equal(custom.decay,0);
console.log('PASS: propagation, corner wrap, rebound, heavy mass, bounded stability, presets and integration-free sleep');
"""
subprocess.run(["node","-e",program],cwd=root,check=True)
