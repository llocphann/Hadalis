#!/usr/bin/env python3
"""Qualify the actual finite wave solver, including corners and sleep."""
from pathlib import Path
import subprocess
root = Path(__file__).resolve().parents[1]
program = (root / "modules/abyss/looks/AbyssWave.js").read_text() + r"""
const assert=require('node:assert/strict');
const p=parameters({preset:'balanced'});
assert.equal(bodyStrength({small:.4,large:1.7,dock:.3,notifications:.2}),1.7);
assert.equal(bodyStrength({strength:2,large:4}),2);
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
        assert(s.displacement.every(v=>Number.isFinite(v)&&Math.abs(v)<=heightLimit(s)+.001));
        assert(s.velocity.every(Number.isFinite));
    }
    assert.equal(s.mode,'SLEEPING',preset+' eventually sleeps under heavy mass');
}
let peaks=[];
for(const preset of Object.keys(presets)) {
    let sample=create(256,1920,1200,parameters({preset})),peak=0;
    impulse(sample,'top',960,160,1,1);
    for(let i=0;i<360;i++) { advance(sample,1/120);peak=Math.max(peak,...sample.displacement.map(Math.abs)); }
    peaks.push(peak);
}
assert(peaks[1]>peaks[0]*2 && peaks[2]>peaks[1]*1.5 && peaks[3]>peaks[2]*1.3,'presets have distinct measured wave heights');
const custom=parameters({preset:'custom',amplitude:9,decay:-1});
assert.equal(custom.amplitude,4);assert.equal(custom.decay,0);
s=create(256,1920,1200,p);
const raw=[20,70,40,95,30,50,80,10],rawBefore=JSON.stringify(raw);
assert(spectrum(s,['top'],raw,100,.8));
const weaker=create(256,1920,1200,p),stronger=create(256,1920,1200,p);
spectrum(weaker,['top'],[1,4,2,5,1,2,3,1],100,1);
spectrum(stronger,['top'],[1,4,2,5,1,2,3,1],100,4);
assert(Math.max(...stronger.spectrumTargets.map(Math.abs))>Math.max(...weaker.spectrumTargets.map(Math.abs))*2,'strength above 100 percent still boosts quiet audio');
assert(s.spectrumTargets.some(v=>v>1) && s.spectrumTargets.some(v=>v<-1),'spectrum is a signed continuous wave');
assert(s.spectrumTargets.every((v,i)=>i*s.length/s.count<=s.width || v===0),'only the selected edge is driven');
assert.equal(JSON.stringify(raw),rawBefore,'shared analyzer frames are never mutated');
for(let i=0;i<1600;i++) advance(s,1/120);
assert.equal(s.mode,'SLEEPING','stationary spectrum can settle without continuous integration');
assert(s.displacement.some(v=>Math.abs(v)>.1),'settled audio keeps its physical wave');
const audioSteps=s.steps;advance(s,.05);assert.equal(s.steps,audioSteps);
assert.equal(spectrum(s,['top'],raw,100,.8),false,'identical audio does not wake the field');
assert(spectrum(s,['left'],raw,100,.8),'edge changes wake and release old targets');
assert(spectrum(s,[],[],100,0),'pause clears audio targets');
for(let i=0;i<1600;i++) advance(s,1/120);
assert.equal(s.mode,'SLEEPING');assert(s.displacement.every(v=>v===0),'pause restores exact flat rest');
for(const bad of [[Infinity,-2,NaN],[0,0,0],[]]) {
    spectrum(s,['top','right','bottom','left'],bad,NaN,100);
    for(let i=0;i<240;i++) advance(s,1/120);
    assert(s.displacement.every(v=>Number.isFinite(v) && Math.abs(v)<=heightLimit(s)+.001),'malformed and extreme audio stays bounded');
}
console.log('PASS: propagation, corner wrap, rebound, heavy mass, bounded stability, presets and integration-free sleep');
"""
subprocess.run(["node","-e",program],cwd=root,check=True)
