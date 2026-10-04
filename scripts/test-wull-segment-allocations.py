#!/usr/bin/env python3
"""QV4 oracle: segment/path results, read/error phases and Qt dependencies."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[1]
args = argparse.ArgumentParser()
args.add_argument("--proposal", action="store_true")
proposal = args.parse_args().proposal
fixture = json.loads((repo / "scripts/fixtures/wull-clear-segment.json").read_text())
source = (repo / fixture["source_path"]).read_text()
start = source.index("function clearSegment(")
end = source.index("\nfunction distance(", start)
candidate = source[start:end]
if proposal:
    candidate = candidate.replace("const lo=[b.x-scene.hostWidth-1.5,b.y-scene.hostHeight-1.5]",
                                  "const loX=b.x-scene.hostWidth-1.5, loY=b.y-scene.hostHeight-1.5")
    candidate = candidate.replace("const hi=[b.x+b.width+1.5,b.y+b.height+1.5]",
                                  "const hiX=b.x+b.width+1.5, hiY=b.y+b.height+1.5")
    candidate = candidate.replace("lo[axis]", "(axis ? loY : loX)").replace("hi[axis]", "(axis ? hiY : hiX)")
if not shutil.which("qs"):
    print("SKIP: Wull allocation oracle requires native Quickshell/QV4")
    raise SystemExit(0)
with tempfile.TemporaryDirectory(prefix="hadalis-wull-segment-") as directory:
    root = Path(directory)
    (root / "Before.js").write_text(source[:start]+fixture["function"]+source[end:])
    (root / "After.js").write_text(source[:start]+candidate+source[end:])
    shutil.copy(repo / "modules/abyss/companion/WullSurfacePlacement.js", root / "WullSurfacePlacement.js")
    (root / "Cases.js").write_text(r'''
.pragma library
function run(old, now) {
 let cases=0, seed=51723;
 function random() {seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296}
 function check(ok,message) {if(!ok)throw new Error(message)}
 function outcome(api,name,args) {
  try{return {result:api[name].apply(null,args)}}catch(e){return {error:e.name+":"+e.message}}
 }
 function observed(value,trace,path,throwAt) {
  if(!value || typeof value!=="object")return value;
  const copy=Array.isArray(value) ? [] : {};
  for(const key of Object.keys(value)) {
   const child=observed(value[key],trace,path+"."+key,throwAt);
   Object.defineProperty(copy,key,{enumerable:true,get:function(){
    const name=path+"."+key;trace.push(name);
    if(name===throwAt)throw new Error("blocked "+name);
    return child;
   }})
  }
  return copy;
 }
 function compare(name,values,throwAt) {
  const a=[],b=[];
  const left=values.map((v,i)=>observed(v,a,"a"+i,throwAt));
  const right=values.map((v,i)=>observed(v,b,"a"+i,throwAt));
  check(JSON.stringify(outcome(old,name,left))===JSON.stringify(outcome(now,name,right)),name+" result/error");
  check(JSON.stringify(a)===JSON.stringify(b),name+" ordered reads");cases++;
 }
 function scene(blockers) {return {width:1000,height:700,hostWidth:80,hostHeight:70,scale:1,
  insets:{left:16,top:16,right:16,bottom:16},records:[],blockers:blockers,surfaces:[]}}
 for(let i=0;i<3500;i++) {
  const blockers=Array.from({length:i%9},()=>({x:80+random()*750,y:80+random()*450,width:10+random()*120,height:10+random()*100}));
  const s=scene(blockers);
  const from={x:2+random()*918,y:2+random()*628},to={x:2+random()*918,y:2+random()*628};
  compare("clearSegment",[s,from,to],"");
  if(i<120)compare("path",[s,from,to],"");
 }
 const obstacle={x:400,y:300,width:100,height:100};
 for(const dx of [0,1e-10,1e-9,-1e-9,500,-500])
  for(const dy of [0,1e-10,1e-9,-1e-9,400,-400])
   for(const x of [318.5,318.500000001,400,501.5,501.499999999])
    compare("clearSegment",[scene([obstacle]),{x:x,y:210},{x:x+dx,y:210+dy}],"");
 const values=[scene([obstacle]),{x:100,y:100},{x:800,y:500}];
 for(const key of ["a0.width","a0.hostWidth","a0.hostHeight","a0.blockers.0.x",
  "a0.blockers.0.y","a0.blockers.0.width","a0.blockers.0.height","a1.x","a1.y","a2.x","a2.y"])
  compare("clearSegment",values,key);
 for(const bad of [null,{},NaN,Infinity,-1]) {
  compare("clearSegment",[bad,values[1],values[2]],"");
  const s=scene([Object.assign({},obstacle,{width:bad})]);compare("clearSegment",[s,values[1],values[2]],"");
 }
 return cases;
}
''')
    (root / "shell.qml").write_text(r'''//@ pragma ShellId hadalis-wull-segment-oracle
import QtQuick
import Quickshell
import "Before.js" as Before
import "After.js" as After
import "Cases.js" as Cases
ShellRoot {
 id:root
 property int step:0
 property int oldNotify:0
 property int newNotify:0
 property QtObject blocker: QtObject {property real x:400;property real y:300;property real width:100;property real height:100}
 property var scene:({width:1000,height:700,hostWidth:80,hostHeight:70,scale:1,
  insets:{left:16,top:16,right:16,bottom:16},records:[],blockers:[root.blocker],surfaces:[]})
 property point from:Qt.point(100,350)
 property point to:Qt.point(800,350)
 readonly property bool before:Before.clearSegment(scene,from,to)
 readonly property bool after:After.clearSegment(scene,from,to)
 onBeforeChanged:oldNotify++
 onAfterChanged:newNotify++
 Component.onCompleted: {
  try {console.info("WULL_SEGMENT_CASES",Cases.run(Before,After))}
  catch(e){console.error("WULL_SEGMENT_FAIL",e);Qt.quit()}
 }
 Timer {interval:10;running:true;repeat:true;onTriggered:{
  if(root.before!==root.after || root.oldNotify!==root.newNotify) {
   console.error("WULL_SEGMENT_FAIL Qt binding/NOTIFY parity",root.step);Qt.quit();return
  }
  if(root.step===12){console.info("WULL_SEGMENT_PASS reactive=13");Qt.quit();return}
  root.blocker.y=root.step%2 ? 300 : 500;
  root.blocker.x=root.step%3 ? 400 : 900;
  root.step++;
 }}
}
''')
    env = dict(os.environ, QT_QPA_PLATFORM="offscreen", XDG_CONFIG_HOME=str(root / "config"),
               XDG_STATE_HOME=str(root / "state"), XDG_CACHE_HOME=str(root / "cache"))
    for key in ("QS_CONFIG_PATH", "QS_CONFIG_NAME", "QS_MANIFEST"):
        env.pop(key, None)
    result = subprocess.run(["timeout", "35s", "qs", "-p", str(root), "--no-color"], env=env,
                            text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if result.returncode or "WULL_SEGMENT_PASS" not in result.stdout or any(e in result.stdout for e in (
            "WULL_SEGMENT_FAIL", "ReferenceError:", "TypeError:", "Binding loop", "Failed to load")):
        print(result.stdout)
        raise SystemExit(1)
    print("\n".join(line for line in result.stdout.splitlines() if "WULL_SEGMENT_" in line))
