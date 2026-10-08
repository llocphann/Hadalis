#!/usr/bin/env python3
"""Real actor/renderer retains the support frame during Jump/Fly, both casts."""
import json,tempfile
from pathlib import Path
from native_test_session import private_wayland,run_qs
ROOT=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="hadalis-airborne-frame-") as name:
 folder=Path(name)
 for entry in ["modules","services","GlobalStates.qml","qmldir","assets","scripts","defaults","translations"]:(folder/entry).symlink_to(ROOT/entry)
 (folder/"shell.qml").write_text(r'''
import QtQuick
import QtTest
import Quickshell
import qs.modules.common
import qs.modules.abyss.companion
ShellRoot {
 id:root
 property real targetX:400
 property real targetY:300
 Component.onCompleted:Quickshell.watchFiles=false
 WullPresence {id:presence;actor:actor;permitted:false}
 FloatingWindow {
  visible:true;width:1000;height:700;color:"#111820"
  AbyssCompanion {
   id:actor;upright:true;managedPlacement:true;presentationManaged:true
   standingAngle:presence.standingAngle;surfaceSupported:presence.grounded
   travelEnabled:presence.traveling;travelMode:presence.mode;travelDuration:5000
   targetX:root.targetX;targetY:root.targetY
  }
 }
 TestCase {
  id:test;when:false;optional:true
  function check(v,m){if(!v)throw new Error(m)}
  function renderer(item){if(item.orientationAngle!==undefined && item.character!==undefined)return item;for(const c of item.children??[]){const r=renderer(c);if(r)return r}return null}
  function runChecks(){try{
   tryCompare(Config,"ready",true,4000)
   let count=0
   for(const character of ["aqua","octo"])for(const edge of ["top","right","bottom","left"])for(const mode of ["jump","fly"]){
    presence.traveling=false;actor.stopTravel();actor.character=character
    presence.placement={grounded:true,edge:edge,support:{edge:edge}}
    actor.adoptTo(400,300,edge,1);root.targetX=400;root.targetY=300
    presence.mode=mode;presence.traveling=true
    root.targetX=440;root.targetY=340;wait(60)
    check(actor.moving && !presence.grounded,"fixture did not exercise airborne animation")
    const expected={top:180,right:-90,bottom:0,left:90}[edge],body=renderer(actor)
    check(body!==null && body.orientationAngle===expected && actor.standingAngle===expected,character+" "+mode+" lost "+edge+" support orientation")
    count++
   }
   presence.traveling=false;presence.placement={grounded:true,edge:"bottom",support:{edge:"bottom"}}
   check(actor.standingAngle===0,"landing did not adopt its new support frame")
   console.info("COMPANION_AIRBORNE_PASS",count,"real cast/edge/mode frames and landing")
  }catch(e){console.error("COMPANION_AIRBORNE_FAIL",e.message,e.stack)}Qt.quit()}
 }
 Timer {interval:100;running:true;onTriggered:test.runChecks()}
}
''')
 with private_wayland(folder) as env:
  if env is None:print("SKIP: airborne actor test requires private Niri");raise SystemExit(0)
  cfg=folder/"config/illogical-impulse";cfg.mkdir(parents=True,exist_ok=True)
  (cfg/"config.json").write_text((ROOT/"defaults/config.json").read_text())
  env["QSG_RHI_BACKEND"]="opengl"
  result=run_qs(folder,env,25)
  if result.returncode or "COMPANION_AIRBORNE_PASS" not in result.stdout or any(x in result.stdout for x in ["COMPANION_AIRBORNE_FAIL","ReferenceError:","TypeError:","Binding loop","Failed to load configuration"]):print(result.stdout);raise SystemExit(1)
  print("COMPANION_AIRBORNE_PASS 16 Aqua/Octo Jump/Fly support orientations; landing adopts new edge")
