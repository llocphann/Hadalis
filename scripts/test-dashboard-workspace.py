#!/usr/bin/env python3
"""Check responsive projection against real defaults and crowded saved layouts."""
from pathlib import Path
import json, subprocess
root=Path(__file__).resolve().parents[1]
defaults=json.loads((root/'defaults/config.json').read_text())['dashboard']['canvas']['widgets']
program=(root/'modules/dashboard/DashboardLayout.js').read_text()+"\nconst defaults="+json.dumps(defaults)+r""";
const assert=require('node:assert/strict');
const minimums={media:{width:320,height:390},weather:{width:280,height:180},calendar:{width:300,height:210},
 todo:{width:260,height:140},notifications:{width:260,height:130},notes:{width:240,height:160},
 agenda:{width:240,height:75},system:{width:260,height:180}};
function verify(result,entries) {
 const visible=entries.filter(p=>p.visible!==false);
 assert.equal(Object.keys(result.rects).length+result.overflow.length,visible.length);
 assert(new Set([...Object.keys(result.rects),...result.overflow]).size===visible.length,'every requested card is placed or reported, never lost');
 for(let i=0;i<visible.length;i++) {
  const r=result.rects[visible[i].id], min=minimums[visible[i].id]||{width:200,height:80};
  if(!r) {assert(result.overflow.includes(visible[i].id));continue;}
  assert(r.width>=min.width-.001 && r.height>=min.height-.001,'readable minimum sizes');
  assert(r.x>=0 && r.y>=0 && r.x+r.width<=result.width+.001 && r.y+r.height<=result.height+.001,'within working space');
  for(let j=0;j<i;j++) if(result.rects[visible[j].id]) assert(!overlaps(r,result.rects[visible[j].id],8),'no projected overlaps');
 }
}

function legacyFreeRect(desired, minimum, width, height, obstacles, gap, shrink) {
    if (minimum.width > width || minimum.height > height) return null;
    var widths=shrink ? [desired.width,minimum.width] : [desired.width];
    var heights=shrink ? [desired.height,minimum.height] : [desired.height];
    var best=null, score=Infinity;
    widths.forEach(function(w) { heights.forEach(function(h) {
        var xs=[desired.x,0,width-w], ys=[desired.y,0,height-h];
        obstacles.forEach(function(other) {
            xs.push(other.x-w-gap,other.x+other.width+gap);
            ys.push(other.y-h-gap,other.y+other.height+gap);
        });
        xs.forEach(function(x) { ys.forEach(function(y) {
            var r={x:x,y:y,width:w,height:h};
            if(x<0 || y<0 || x+w>width+.001 || y+h>height+.001
                    || obstacles.some(function(other) { return overlaps(r,other,gap); })) return;
            var cost=Math.pow(x-desired.x,2)+Math.pow(y-desired.y,2)
                +4*(Math.pow(w-desired.width,2)+Math.pow(h-desired.height,2));
            if(cost<score) { best=r;score=cost; }
        }); });
    }); });
    return best;
}
function assertFreeRectParity(label, args) {
    assert.deepEqual(freeRect(...args, true), legacyFreeRect(...args), label);
}
const oracleMinimum={width:40,height:30};
[
 ['empty obstacles',[{x:10,y:10,width:90,height:70},oracleMinimum,320,220,[],8,true]],
 ['disjoint obstacles',[{x:20,y:20,width:100,height:80},oracleMinimum,360,240,
   [{x:210,y:120,width:70,height:60}],8,true]],
 ['colliding obstacles',[{x:40,y:40,width:120,height:90},oracleMinimum,360,240,
   [{x:35,y:35,width:110,height:85},{x:200,y:40,width:80,height:100}],8,true]],
 ['duplicate candidate axes',[{x:0,y:0,width:100,height:80},oracleMinimum,300,220,
   [{x:108,y:0,width:80,height:80},{x:108,y:88,width:80,height:80}],8,true]],
 ['tie ordering',[{x:100,y:70,width:80,height:60},oracleMinimum,280,200,
   [{x:90,y:60,width:100,height:80}],0,true]],
 ['NaN gap',[{x:10,y:10,width:80,height:60},oracleMinimum,260,180,
   [{x:120,y:20,width:60,height:60}],NaN,true]],
 ['Infinity obstacle',[{x:10,y:10,width:80,height:60},oracleMinimum,260,180,
   [{x:Infinity,y:20,width:60,height:60}],8,true]],
 ['negative zero',[{x:-0,y:-0,width:80,height:60},oracleMinimum,260,180,
   [{x:120,y:20,width:60,height:60}],-0,true]],
].forEach(([label,args])=>assertFreeRectParity(label,args));
function coercingGap(counter) {
    return { valueOf() { counter.count++; return 8; } };
}
const coercionArgs=[{x:20,y:20,width:100,height:80},oracleMinimum,320,220,
    [{x:150,y:20,width:80,height:80}],null,true];
const oldCounter={count:0}, newCounter={count:0};
coercionArgs[5]=coercingGap(oldCounter);
const oldCoercion=legacyFreeRect(...coercionArgs);
coercionArgs[5]=coercingGap(newCounter);
const newCoercion=freeRect(...coercionArgs,true);
assert.deepEqual(newCoercion,oldCoercion,'nonprimitive gap fallback preserves result');
assert.equal(newCounter.count,oldCounter.count,'nonprimitive gap fallback preserves coercion count');

const before=JSON.stringify(defaults);
for(const [w,h] of [[1200,620],[640,360],[320,200],[1800,1000]]) {
 const result=project(defaults,w,h,minimums,8,{width:9000,height:9000});verify(result,defaults);
 assert.equal(result.width,w,'body width bounds working space');assert.equal(result.height,h,'body height bounds working space');
 assert.deepEqual(project(defaults,w,h,minimums,8,{}),result,'legacy scroll reference cannot expand canvas');
 const saved=defaults.map(p=>{
  const r=result.rects[p.id];return r?{id:p.id,x:r.x/result.width,y:r.y/result.height,w:r.width/result.width,h:r.height/result.height,visible:true}:p;
 });
 const reopened=project(saved,w,h,minimums,8,{width:result.width,height:result.height});verify(reopened,saved);
 assert(reopened.width===w && reopened.height===h,'saved coordinate space stays stable');
 for(const id of Object.keys(result.rects)) for(const key of ['x','y','width','height'])
  assert(Math.abs(reopened.rects[id][key]-result.rects[id][key])<2,'save/reopen preserves geometry');
}
const crowded=defaults.map(p=>({...p,x:.2,y:.1,w:.4,h:.3,visible:true}));
verify(project(crowded,900,520,minimums,8,{}),crowded);
assert.equal(JSON.stringify(defaults),before,'projection never edits saved preferences');
const empty=project(defaults.map(p=>({...p,visible:false})),400,300,minimums,8,{});
assert.deepEqual(empty,{width:400,height:300,rects:{},overflow:[]},'empty layout retains its viewport');
const malformed=defaults.map(p=>({...p,x:NaN,y:Infinity,w:NaN,h:-1}));
verify(project(malformed,640,360,minimums,8,{}),malformed);
const packed=[{id:'notes',x:0,y:0,w:1,h:1,visible:true},{id:'system',x:0,y:0,w:1,h:1,visible:true}];
const crowdedResult=project(packed,240,160,minimums,8,{});
assert.deepEqual(crowdedResult.overflow,['system'],'no room never grows the finite body or overlaps the previous card');
console.log('PASS: finite Dashboard bounds, readable cards, explicit overflow, legacy-reference migration, stable save/reopen and malformed geometry');
"""
subprocess.run(['node','-e',program],cwd=root,check=True)
