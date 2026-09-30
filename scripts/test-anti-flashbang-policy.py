#!/usr/bin/env python3
"""Qualify finite, monotonic dimming and settings rather than QML spelling."""
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parents[1]
program = (root / "services/antiFlashbangPolicy.js").read_text() + r"""
const assert=require('node:assert/strict');
assert.equal(multiplier(0),1,'dark content cannot amplify the selected brightness');
assert.equal(multiplier(30),1,'the default threshold leaves dark content unchanged');
assert(multiplier(100)<.25,'white content is strongly dimmed by default');
for(const options of [{},{strength:0},{strength:1,minMultiplier:.05},
    {threshold:.95},{threshold:-100,strength:Infinity,minMultiplier:NaN}]) {
    let previous=1;
    for(let lightness=0;lightness<=100;lightness++) {
        const gain=multiplier(lightness,options);
        assert(Number.isFinite(gain)&&gain>=.05&&gain<=1);
        assert(gain<=previous+1e-12,'brighter content never increases gain');previous=gain;
    }
}
for(const sample of [NaN,Infinity,-1,101,'invalid']) assert.equal(multiplier(sample),1);
assert.equal(multiplier(100,{strength:0}),1);
assert(Math.abs(multiplier(100,{strength:1,minMultiplier:.30})-.30)<1e-12);
assert(multiplier(60,{threshold:.10})<multiplier(60,{threshold:.50}),'threshold changes sensitivity');
assert(multiplier(80,{strength:1})<multiplier(80,{strength:.50}),'strength changes dimming');
assert.equal(bounded(NaN,500,250,3000),500);
assert.equal(bounded(1,500,250,3000),250);
console.log('PASS: finite dim-only response, threshold, strength, readable floor and malformed settings');
"""
subprocess.run(["node", "-e", program], check=True)
