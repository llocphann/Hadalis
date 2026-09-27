#!/usr/bin/env python3
"""Exercise production placement normalization, packing and output profiles."""
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parents[1]
program = (root / "modules/abyss/looks/AbyssLayout.js").read_text() + r"""
const assert = require('node:assert/strict');
for (const edge of ['top','right','bottom','left']) {
 const shared={edge,size:1,customSize:false}, custom={...shared,size:1.3,customSize:true};
 assert.equal(moduleSize(shared,{edgeThickness:32}),2,'thicker Edge scales shared modules');
 assert.equal(moduleSize(shared,{edgeThickness:10}),.625,'narrower Edge scales shared modules');
 assert.equal(moduleSize(custom,{edgeThickness:32}),1.3,'explicit custom size stays independent');
 assert.equal(moduleSize(shared,{edgeThickness:Infinity}),1,'invalid thickness is bounded');
}

assert(!catalog.includes('leftSidebarButton') && !catalog.includes('rightSidebarButton'));
assert.deepEqual(normalize([{id:'old-left',kind:'leftSidebarButton'},{id:'clock',kind:'clock'},{id:'old-right',kind:'rightSidebarButton'}],'top').map(p=>p.id),['clock']);
const initial = seed([catalog.slice(0,3),catalog.slice(3,5),[catalog[5]],catalog.slice(6,9),catalog.slice(9)],'top',1920,1200);
assert.equal(initial.length,catalog.length);
assert.equal(new Set(initial.map(p=>p.id)).size,initial.length);
assert(normalize([{kind:'clock',joinCorner:true}],'top')[0].joinCorner);
assert(!normalize([{kind:'clock'}],'top')[0].joinCorner);
for (const edge of ['top','right','bottom','left']) {
 const horizontal=edge==='top'||edge==='bottom', length=horizontal?1920:1200;
 assert.equal(adjacentEdge({edge,along:40,span:100},1920,1200),horizontal?'left':'top');
 assert.equal(adjacentEdge({edge,along:length-140,span:100},1920,1200),horizontal?'right':'bottom');
 assert.equal(adjacentEdge({edge,along:length/2,span:100},1920,1200),'');
}

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
const measured=geometry(initial.filter(p=>['clock','timer'].includes(p.kind)),1920,1200,{extents:{clock:300,timer:0}},1.5);
assert.equal(measured.find(p=>p.kind==='clock').span,300,'mature module sizes already include font scale');
assert.equal(measured.find(p=>p.kind==='timer').span,0,'idle indicators have no empty input');
assert(geometry(initial,1920,1200,{extents:{timer:0},editing:true},1).find(p=>p.kind==='timer').span>0,'editor can select inactive indicators');
const sized=normalize([{id:'a',kind:'clock',edge:'top',position:.1},{id:'b',kind:'clock',edge:'top',position:.4},
    {id:'c',kind:'clock',edge:'right',position:.5},{id:'custom',kind:'clock',edge:'top',position:.8,size:1.6,customSize:true}], 'top');
const sizing={edgeSizes:{top:1.25,right:.8},extents:{a:100,b:100,c:100,custom:100}};
const sizes=geometry(sized,1920,1200,sizing,1);
assert.equal(sizes.find(p=>p.id==='a').span,125);assert.equal(sizes.find(p=>p.id==='b').span,125,'one edge inherits one size');
assert.equal(sizes.find(p=>p.id==='c').span,80,'another edge can have another size');
assert.equal(sizes.find(p=>p.id==='custom').span,160,'explicit custom size overrides shared edge size');
assert.equal(stripDepth(sized,'top',sizing,1),67.2,'reservation contains the largest custom module');
assert(normalize([{kind:'clock',size:1.3}], 'top')[0].customSize,'historic non-default sizes migrate to explicit overrides');
assert(!normalize([{kind:'clock',size:1.3,customSize:false}], 'top')[0].customSize,'unchecked override inherits even when old size is saved');
const inherited=saveProfile({edgeSizes:{top:1},outputLayouts:[{outputName:'B',placements:[],edgeSizes:{top:.7}}]},'A',sized,8,true,sizing.edgeSizes);
assert.equal(optionsForOutput({outputLayouts:inherited['abyss.modules.outputLayouts']},'A').edgeSizes.top,1.25);
assert.equal(inherited['abyss.modules.outputLayouts'][0].edgeSizes.top,.7,'save preserves another output size');
for(const edge of ['top','right','bottom','left']) {
    const aligned=normalize([{id:'a',kind:'clock',edge,position:.2,alignment:'center'},
        {id:'b',kind:'clock',edge,position:.4,alignment:'center'}],edge);
    const length=['top','bottom'].includes(edge)?1920:1200;
    for(const alignment of ['start','center','end']) {
        const group=geometry(aligned.map(p=>({...p,alignment})),1920,1200,{gap:8,extents:{a:100,b:100}},1);
        assert.equal(group[1].along-group[0].along,108,'aligned groups preserve order and gap');
        assert.equal(group[0].along,alignment==='start'?34:alignment==='end'?length-34-208:(length-208)/2);
    }
}
const solo=normalize([{id:'clock',kind:'clock',edge:'top',position:.2}], 'top');
const snapped=snapMove(solo,'clock',964,10,1920,1200,{extents:{clock:100}},1);
assert.equal(snapped.placements[0].position,.5);assert.equal(snapped.guides[0].along,960);
assert.equal(snapMove(solo,'clock',990,10,1920,1200,{},1).guides.length,0,'outside tolerance stays free');
assert.equal(snapMove(solo,'clock',1900,601,1920,1200,{},1).guides[0].horizontal,false,'vertical edge uses horizontal guide');
assert.equal(move([{...solo[0],alignment:'center'}],'clock',600,10,1920,1200)[0].alignment,'free','drag releases group alignment');
console.log('PASS: normalized module packing, all edges/scales, output profiles, disabled state and bounded malformed input');
"""
subprocess.run(["node", "-e", program], cwd=root, check=True)
