#!/usr/bin/env python3
"""Owned native portal handover, invalidation and grounded roll contracts."""
import json,tempfile
from pathlib import Path
from native_test_session import private_wayland,run_qs
ROOT=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='hadalis-wull-portal-') as name:
 folder=Path(name)
 for entry in ['modules','services','GlobalStates.qml','qmldir','assets','scripts','defaults','translations']:(folder/entry).symlink_to(ROOT/entry)
 (folder/'shell.qml').write_text(r'''
import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import qs.modules.common
import qs.modules.abyss.companion
import "modules/abyss/companion/WullScene.js" as Scene
Window {
 id:root;visible:true;width:1280;height:820;color:"#111820"
 Component.onCompleted:Quickshell.watchFiles=false
 property bool blocked:false
 property bool animate:true
 property bool held:false
 property var scene:({width:1280,height:820,scale:1,hostWidth:112,hostHeight:98,insets:{top:20,right:20,bottom:20,left:20},records:[],surfaces:[],blockers:blocked ? [{x:1020,y:690,width:200,height:125}] : []})
 WullPresence {
  id:presence;scene:root.scene;actor:actor;permitted:true;requestedReveal:1;motionEnabled:root.animate;interactionHeld:root.held
  onStopRequested:actor.stopTravel()
  onResetRequested:(px,py,edge)=>actor.resetTo(px,py,edge)
 }
 WullPortals {id:portals;presence:presence;z:2}
 AbyssCompanion {
  id:actor;z:3;character:"aqua";upright:true;managedPlacement:true;motionEnabled:root.animate;effectsEnabled:false
  targetX:presence.targetX;targetY:presence.targetY;reveal:presence.renderedReveal;edge:presence.emergenceEdge;emergenceEdge:presence.emergenceEdge;standingAngle:presence.standingAngle
  travelEnabled:presence.traveling && !presence.portalActive;travelMode:presence.mode;travelDuration:presence.duration;travelArc:presence.arc;travelDirection:presence.directionX;surfaceSupported:presence.grounded;portalReveal:presence.portalReveal
  onTravelCompleted:presence.arrived()
 }
 TestCase {
  id:test;when:false;optional:true
  function check(value,message){if(!value)throw new Error(message)}
  function find(item,name){if(item.objectName===name)return item;for(const child of item.children ?? []){const found=find(child,name);if(found)return found}return null}
  function put(fraction){
   presence.hideImmediately();root.blocked=false;root.animate=true;root.held=false
   const p=Scene.edgePoint(root.scene,"bottom",fraction)
   presence.placement=p;presence.destination=p;presence.targetX=p.x;presence.targetY=p.y;presence.visitActive=true;presence.peekIntro=false;presence.peekOnly=false;presence.renderedReveal=1
   actor.adoptTo(p.x,p.y,"bottom",1);wait(100)
   check(actor.inputReady && presence.grounded,"fixture could not establish a grounded visit")
   return p
  }
  function runChecks(){try {
   tryCompare(Config,"ready",true,4000)
   Config.setNestedValues({"panelFamily":"abyss","performance.reduceAnimations":false})
   let source=put(.15),dest=Scene.edgePoint(root.scene,"bottom",.9)
   check(presence.moveTo(dest,false),"long destination rejected")
   check(presence.portalActive && presence.traveling && !actor.moving,"long travel did not choose portal")
   tryVerify(()=>presence.portalProgress>.42 && presence.portalProgress<.49,1200)
   check(Scene.distance(presence.position(),source)<.2 && actor.portalReveal===0 && !actor.inputReady,"source moved or retained input before hidden handover")
   check(find(portals,"wullPortalSource") && find(portals,"wullPortalDestination"),"paired water openings are absent")
   tryVerify(()=>presence.portalHopped && presence.portalProgress<.59,500)
   check(Scene.distance(presence.position(),dest)<.2 && actor.portalReveal===0,"handover was visible or missed its destination")
   tryCompare(presence,"portalActive",false,1600)
   check(!portals.visible && actor.inputReady && presence.grounded,"portal did not settle or stop drawing")
   source=put(.15);dest=Scene.edgePoint(root.scene,"bottom",.9);presence.moveTo(dest,false);wait(300)
   root.blocked=true;wait(150)
   check(!presence.portalActive && Scene.distance(presence.position(),source)<.2,"blocked destination retained a stale portal")
   wait(1600);check(Scene.distance(presence.position(),source)<.2,"cancelled portal moved later")
   source=put(.15);presence.moveTo(Scene.edgePoint(root.scene,"bottom",.9),false);wait(300);root.animate=false;wait(150)
   check(!presence.portalActive && actor.portalReveal===1 && actor.inputReady,"reduced motion left a hidden actor")
   source=put(.15);presence.moveTo(Scene.edgePoint(root.scene,"bottom",.9),false);wait(300);root.held=true;wait(150)
   check(!presence.portalActive && actor.inputReady,"interaction did not cancel portal")
   source=put(.15);presence.moveTo(Scene.edgePoint(root.scene,"bottom",.9),false);wait(300)
   presence.beginTurn("pulled");wait(100)
   check(!presence.portalActive && !actor.inputReady,"cast handoff retained an active portal or input")
   wait(1600);check(Scene.distance(presence.position(),source)<.2,"cast handoff retained a delayed teleport")
   presence.handoffActive=false
   source=put(.3);dest=Scene.annotate(root.scene,{x:source.x+70,y:source.y},"bottom","edge","bottom")
   check(presence.moveTo(dest,false,"roll"),"grounded roll rejected")
   wait(350)
   const body=find(actor,"wullLiquidBody")
   check(actor.rolling && !actor.flying && presence.grounded && Math.abs(body.rollingAngle)>20,"roll did not rotate the native body on its surface")
   tryCompare(presence,"traveling",false,presence.duration+700)
   check(!actor.rolling && body.rollingAngle===0 && actor.inputReady && Scene.distance(presence.position(),dest)<.2,"roll did not finish upright at destination")
   console.info("WULL_PORTAL_NATIVE_PASS hidden-handover destination-invalidation bounded-lifetime motion-cancel interaction-cancel cast-cancel grounded-roll")
  }catch(e){console.error("WULL_PORTAL_NATIVE_FAIL",e.message,e.stack)}Qt.quit()}
 }
 Timer {interval:100;running:true;onTriggered:test.runChecks()}
}
''')
 with private_wayland(folder) as env:
  if env is None:print('SKIP: native Wull portal requires private Niri');raise SystemExit(0)
  conf=folder/'config/illogical-impulse';conf.mkdir(parents=True,exist_ok=True)
  config=json.loads((ROOT/'defaults/config.json').read_text());config['panelFamily']='abyss';(conf/'config.json').write_text(json.dumps(config))
  result=run_qs(folder,env,timeout=30);output=result.stdout
  if result.returncode or 'WULL_PORTAL_NATIVE_PASS' not in output or any(e in output for e in ['WULL_PORTAL_NATIVE_FAIL','ReferenceError:','TypeError:','Unable to assign','Binding loop','Failed to load configuration']):print(output);raise SystemExit(1)
  for line in output.splitlines():
   if 'WULL_PORTAL_NATIVE_PASS' in line:print(line)
