#!/usr/bin/env python3
"""Exercise adaptive editor geometry on all edges and congested outputs."""
from pathlib import Path
import subprocess

source = (Path(__file__).resolve().parents[1] /
          "modules/background/widgets/DesktopWidgetEditorPlacement.js").read_text()
subprocess.run(["node", "-e", source + r'''
const assert=require('node:assert/strict');
const work={left:16,top:48,right:1184,bottom:784};
const fullBottom={x:0,y:680,width:1200,height:120,key:"bottom"};
const fullTop={x:0,y:0,width:1200,height:130,key:"top"};
assert.equal(choose(work,[],"").edge,"bottom");
assert.equal(choose(work,[fullBottom],"").edge,"top");
assert.equal(choose(work,[fullBottom,fullTop],"").edge,"left");
assert.equal(choose(work,[fullBottom,fullTop,{x:0,y:0,width:110,height:800}],"").edge,"right");
const small={left:3.5,top:20.25,right:390.75,bottom:680.5};
for(const area of [work,small,{left:0,top:0,right:1920,bottom:1080}]) {
 for(let i=0;i<1000;i++) {
  const widgets=Array.from({length:8},(_,n)=>({key:"w"+n,
   x:(i*97+n*127)%area.right,y:(i*61+n*211)%area.bottom,width:100+n*30,height:70+n*10}));
  const p=choose(area,widgets,"w0");
  assert.ok(p.x>=area.left && p.y>=area.top);
  assert.ok(p.x+p.width<=area.right+1e-9 && p.y+p.height<=area.bottom+1e-9);
  assert.deepEqual(choose(area,widgets,"w0"),p,"stable tie/order without orientation feedback");
 }
}
const side=choose(work,[{x:380,y:680,width:440,height:120}],"");
assert.equal(side.edge,"top","a blocked center does not cover a widget");
const crowded=[fullBottom,fullTop,{x:0,y:0,width:1200,height:800,key:"all"}];
assert.ok(Number.isFinite(choose(work,crowded,"all").along));
assert.deepEqual(choose(work,[{x:NaN,y:0,width:10,height:10}],""),choose(work,[],""));
console.log("PASS: adaptive widget editor placement, 3000 bounded deterministic crowded layouts and all four edges");
'''], check=True)
