#!/usr/bin/env python3
"""Exercise the actual allocator and animated union geometry on every Edge."""
from pathlib import Path
import subprocess
root=Path(__file__).resolve().parents[1]
program=(root/'modules/abyss/looks/AbyssGeometry.js').read_text()+"\n"+(root/'modules/abyss/looks/AbyssBodyPlacement.js').read_text()+r'''
const assert=require('node:assert/strict'), edgeInsets={left:16,right:16,top:48,bottom:16};
function overlap(a,b) { return a.x<b.x+b.width && a.x+a.width>b.x && a.y<b.y+b.height && a.y+a.height>b.y }
function request(id,edge,order,depth=200,along=300,span=420) {
 return {id,open:true,order,record:panel(1200,900,edgeInsets,edge,along,span,depth,1,14,[],true)};
}
function verify(requests,result) {
 const rects=[];
 for(const r of requests) if(result[r.id]?.visible) {
  const p=result[r.id];
  const record=placedPanel(1200,900,edgeInsets,r.record.edge,r.record.along,r.record.span,r.record.targetDepth,1,14,[],true,p);
  assert.deepEqual(record.content,p.content,'field, content and allocation share exact coordinates');
  const c=record.content;
  assert(c.x>=edgeInsets.left && c.y>=edgeInsets.top && c.x+c.width<=1184 && c.y+c.height<=884,'inside viewport');
  for(const other of rects) assert(!overlap(c,other),'no content overlaps across or along Edges');
  assert.equal(c.width,r.record.content.width);assert.equal(c.height,r.record.content.height);
  rects.push(c);
 }
}
for(const edge of ['top','bottom','left','right']) {
 const requests=[request('old',edge,1),request('middle',edge,2),request('new',edge,3)];
 const snapshot=JSON.stringify(requests), result=arrange(requests,1200,900,edgeInsets);
 verify(requests,result);assert.equal(result.new.inward,0);
 assert(result.old.inward>result.middle.inward && result.middle.inward>0,'inward pyramid preserves opening order');
 assert.equal(JSON.stringify(requests),snapshot,'does not mutate saved requests');
 const fading=placedPanel(1200,900,edgeInsets,edge,300,420,200,.4,14,[],true,result.old);
 assert.equal(fading.targetDepth,200+result.old.inward,'closing does not change allocation');
}
const crowded=[request('settings','bottom',1,760,80,1040),request('osd','bottom',2,200,400,420)];
const packed=arrange(crowded,1200,900,edgeInsets);verify(crowded,packed);
assert(packed.osd.visible && !packed.settings.visible,'newer wins when no readable space remains');
crowded[1].open=false;assert(arrange(crowded,1200,900,edgeInsets).settings.visible,'closing restores older body');
const mixed=[request('left','left',1,350,100,600),request('top','top',2,260,100,600),request('bottom','bottom',3,320,180,700),request('right','right',4,290,160,500)];
verify(mixed,arrange(mixed,1200,900,edgeInsets));
mixed[0].priority=2;assert.equal(arrange(mixed,1200,900,edgeInsets).left.inward,0,'modal body retains priority');
assert.deepEqual(arrange([],1200,900,edgeInsets),{});
console.log('PASS: all Edge tiers, constrained newest-first fallback/restoration, perpendicular collisions, modal priority and exact union/content geometry');
'''
raise SystemExit(subprocess.run(['node','-e',program],cwd=root).returncode)
