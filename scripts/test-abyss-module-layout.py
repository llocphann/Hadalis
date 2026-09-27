#!/usr/bin/env python3
"""Exercise production placement normalization, packing and output profiles."""
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parents[1]
program = (root / "modules/abyss/looks/AbyssLayout.js").read_text() + r"""
const assert = require('node:assert/strict');
const initial = seed([catalog.slice(0,3),catalog.slice(3,5),['workspaces'],catalog.slice(6,9),catalog.slice(9)],'top',1920,1200);
assert.equal(initial.length,catalog.length);
assert.equal(new Set(initial.map(p=>p.id)).size,initial.length);
const saved = JSON.stringify(initial);
for (const [w,h] of [[1920,1200],[1536,960],[960,600],[480,320]]) {
    for (const edge of ['top','right','bottom','left']) {
        const placements=initial.map(p=>({...p,edge}));
        const records=geometry(placements,w,h,{gap:12},1.5);
        assert.equal(records.length,placements.length);
        for (let i=0;i<records.length;i++) {
            const r=records[i],c=r.content;
            assert(c.x>=0 && c.y>=0 && c.x+c.width<=w+.001 && c.y+c.height<=h+.001);
            assert(r.span>0);
            if(i) assert(records[i-1].along+records[i-1].span <= r.along+.001,'no overlapping controls');
        }
    }
}
assert.equal(JSON.stringify(initial),saved,'resize never mutates persisted layout');
const disabled=initial.map((p,i)=>({...p,enabled:i!==0}));
assert.equal(geometry(disabled,1920,1200,{},1).length,initial.length-1);
const bad=normalize([{kind:'clock',position:Infinity,edge:'unknown'},{kind:'clock'},null,{kind:'unknown'},{kind:'media',size:100,depth:-3}], 'left');
assert.equal(bad.length,2);assert.equal(bad[0].edge,'left');assert.equal(bad[0].position,.5);
assert.equal(bad[1].size,1.8);assert.equal(bad[1].depth,.5);
const profile={configured:true,placements:initial,outputLayouts:[{outputName:'B',placements:[]}]};
assert.deepEqual(resolve(profile,'B',initial),[],'explicit empty output layout stays empty');
assert.deepEqual(resolve(profile,'A',[]),initial);
assert.deepEqual(resolve({configured:false},'A',initial),initial);
assert.equal(normalize(Array(100).fill(0).map((_,i)=>({id:String(i),kind:'clock'})),'top').length,24,'bounded renderer capacity');
const cross=move(initial,'clock',1890,540,1920,1080);
assert.equal(cross.find(p=>p.id==='clock').edge,'right');
assert.equal(cross.find(p=>p.id==='clock').position,.5);
assert.equal(initial.find(p=>p.id==='clock').edge,'top','draft does not mutate saved snapshot');
assert.equal(project(20,1060,1920,1080).edge,'bottom','corner projection deterministic');
const merged=saveProfile({outputLayouts:[{outputName:'B',placements:[],gap:3}]},'A',cross,16,true);
assert.equal(merged['abyss.modules.outputLayouts'][0].outputName,'B','save preserves another output');
assert.equal(optionsForOutput({gap:8,outputLayouts:merged['abyss.modules.outputLayouts']},'A').gap,16);
console.log('PASS: normalized module packing, all edges/scales, output profiles, disabled state and bounded malformed input');
"""
subprocess.run(["node", "-e", program], cwd=root, check=True)
