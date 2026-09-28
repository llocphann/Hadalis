#!/usr/bin/env python3
"""Exercise popup/IPC position inheritance, output routing and bounded placement."""
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parents[1]
program = (root / "modules/abyss/looks/AbyssPresentation.js").read_text() + r"""
const assert=require('node:assert/strict');
const positions=[{kind:'popup',edge:'bottom',alignment:'center'},
 {kind:'clock',edge:'left',alignment:'start'},
 {kind:'clock',outputName:'A',edge:'right',alignment:'end'},
 {kind:'osd',edge:'top',alignment:'center'},
 {kind:'volume',outputName:'B',edge:'bottom',alignment:'custom',position:.25},null];
assert.equal(resolve(positions,'calendar','A').edge,'right','per-output kind wins');
assert.equal(resolve(positions,'calendar','B').edge,'left','global kind beats category');
assert.equal(resolve(positions,'weather','A').edge,'bottom','bar popup inherits category');
for(const kind of ['wifi','bluetooth','utilities']) assert.equal(resolve(positions,kind,'A').edge,'bottom','connected popups inherit the common popup position');
assert.equal(resolve(positions,'volume','A').edge,'top','IPC indicator inherits OSD category');
assert.equal(resolve(positions,'volume','B').position,.25);
assert.equal(resolve(positions,'mediaOsd','A').edge,'top','media OSD stays separate from media popup');
assert.equal(edge({edge:'garbage'},'bottom'),'bottom');
assert.equal(along({},'top',200,1920,1200,530,{}),530,'default follows source anchor');
assert.equal(along({edge:'left'},'left',200,1920,1200,530,{}),500,'edge override centers without ambiguous source axis');
for(const edgeName of edges) {
 for(const [w,h] of [[1920,1200],[960,600],[480,320]]) {
  const length=['top','bottom'].includes(edgeName)?w:h;
  for(const alignment of ['start','center','end','custom']) {
   for(const position of [-3,0,.25,.5,1,3,Infinity,NaN]) {
    const start=along({alignment,position},edgeName,120,w,h,0,{top:48,left:16,right:16,bottom:74});
    assert(Number.isFinite(start) && start>=0 && start+120<=length,'bounded position on all edges/scales');
   }
  }
 }
}
const before=JSON.stringify(positions);
const saved=save(positions,'volume','A',{edge:'right',alignment:'end'});
assert.equal(resolve(saved,'volume','A').edge,'right');
assert.equal(resolve(saved,'volume','B').position,.25,'another output stays intact');
assert.equal(JSON.stringify(positions),before,'save does not mutate stale config snapshot');
assert.equal(resolve(save(saved,'volume','A',null),'volume','A').edge,'top','reset restores inherited category');
console.log('PASS: popup/IPC position inheritance, output isolation, reset and bounds across edges/scales');
"""
subprocess.run(["node", "-e", program], cwd=root, check=True)
