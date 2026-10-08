#!/usr/bin/env python3
"""Composed field/editor across four edges, two surface sizes and both routes."""
import json, tempfile
from pathlib import Path
from native_test_session import private_wayland, run_qs
ROOT=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="hadalis-dashboard-editor-field-") as name:
 folder=Path(name)
 for entry in ["modules","services","GlobalStates.qml","qmldir","assets","scripts","defaults","translations"]:(folder/entry).symlink_to(ROOT/entry)
 (folder/"shell.qml").write_text(r'''
import QtQuick
import QtTest
import Quickshell
import qs
import qs.modules.common
import qs.services
import qs.modules.abyss
import qs.modules.abyss.looks
ShellRoot {
 id:root
 property bool shown:false
 property string route:"Dashboard"
 property string edge:"bottom"
 property real surfaceWidth:1280
 property real surfaceHeight:900
 property string caseName:""
 Component.onCompleted:Quickshell.watchFiles=false
 FloatingWindow {
  id:window;visible:true;implicitWidth:1280;implicitHeight:900;color:"#111820"
  // A compositor may retain the native window size. Exercise the allocated
  // field dimensions explicitly instead of treating a resize request as proof.
  Item {
  id:surface;width:root.surfaceWidth;height:root.surfaceHeight
  AbyssSurfaceController {id:liquid;outputWidth:surface.width;outputHeight:surface.height;presentationItem:surface;edgeInsets:({top:16,left:16,right:16,bottom:16})}
  AbyssField {id:field;anchors.fill:parent;records:liquid.records;waveTexture:liquid.waves.texture;edgeInsets:liquid.edgeInsets}
  AbyssBodyHost {
   id:body;anchors.fill:parent;controller:liquid;identity:"dashboard";edge:root.edge
   open:root.shown;animatePresentation:false;animatePlacementChanges:false
   stableContentSize:true;largeSurface:true;edgeInsets:liquid.edgeInsets
   span: ["top","bottom"].includes(edge) ? width*.76 : height*.70
   depth:["top","bottom"].includes(edge) ? height*.70 : width*.76
   along:((["top","bottom"].includes(edge)?width:height)-span)/2
   source:Qt.resolvedUrl("modules/abyss/content/Abyss"+root.route+"Content.qml")
  }
  }
 }
 TestCase {
  id:test;when:false;optional:true
  SignalSpy {id:clickSpy;signalName:"clicked"}
  function check(v,m){if(!v)throw new Error(root.caseName+": "+m)}
  function find(item,p){if(p(item))return item;for(const c of item.children??[]){const x=find(c,p);if(x)return x}return null}
  function clickAction(popup,name){
   const button=findChild(popup,name)
   check(button?.visible && button.enabled,"action unavailable: "+name)
   // Hiding a card changes the Add row and can schedule a toolbar relayout.
   // Map the native click only after the pending layout has finished.
   check(waitForPolish(surface.Window.window,1500),"pending editor layout: "+name)
   clickSpy.target=button;clickSpy.clear()
   mouseClick(button)
   tryCompare(clickSpy,"count",1,1000)
  }
  function runChecks(){try{
   tryCompare(Config,"ready",true,4000)
   Config.setNestedValues({"performance.reduceAnimations":true,"dashboard.showHeader":false})
   GlobalStates.deferredPanelsReady=true;GlobalStates.overviewMode="dashboard"
   tryCompare(field,"ready",true,4000)
   let count=0
   for(const size of [[1280,900],[720,650]])for(const route of ["Dashboard","Overview"])for(const edge of ["top","right","bottom","left"]){
    root.caseName=JSON.stringify([size,route,edge])
    root.shown=false;wait(100);root.surfaceWidth=size[0];root.surfaceHeight=size[1];root.route=route;root.edge=edge;root.shown=true
    check(surface.width===size[0] && surface.height===size[1],"field allocation did not resize")
    tryVerify(()=>body.contentItem.item!==null,5000)
    const canvas=find(body.contentItem.item,i=>typeof i.beginResize==="function")
    check(canvas!==null,"missing canvas "+route)
    Config.setNestedValue("dashboard.canvas.widgets",canvas.defaultEntries().map(p=>Object.assign({},p,{visible:p.id==="notes",x:.15,y:.15,w:.3,h:.35})))
    wait(80)
    // Empty placeholders and long drafts must not drive card width or lose
    // vertical scrolling as the real hosts resize/reload the notes editor.
    tryCompare(Notepad,"ready",true,4000)
    const note=find(canvas,i=>typeof i.placeholderText==="string" && typeof i.cursorPosition==="number" && typeof i.wrapMode==="number")
    check(note!==null,"notes editor missing")
    const draft=note.text
    note.text="";wait(40)
    check(note.placeholderText.length>0,"empty notes lost their placeholder")
    note.text=("A wrapped note remains editable throughout Dashboard resizing. ").repeat(12)+"\n"+("A separate draft line.\n").repeat(60)
    wait(60)
    let viewport=note.parent
    while(viewport && typeof viewport.contentY!=="number")viewport=viewport.parent
    check(viewport!==null && viewport.contentHeight>viewport.height,"long notes cannot scroll")
    check(viewport.contentHeight>=note.contentHeight && viewport.contentWidth<=viewport.width+1,"notes have clipped text or a horizontal scroll extent")
    viewport.contentY=Math.max(0,viewport.contentHeight-viewport.height);wait(20)
    check(viewport.contentY+viewport.height>=note.contentHeight,"last note line is unreachable")
    note.text=draft;wait(40)
    const dimensions=[canvas.width,canvas.height],saved=JSON.stringify(Config.options.dashboard.canvas.widgets)
    canvas.beginEditMode();wait(120)
    const popup=find(surface,i=>i.objectName==="abyssDashboardEditPopup" && i.canvasController===canvas)
    check(popup?.visible,"editor did not join output field")
    check(canvas.width===dimensions[0] && canvas.height===dimensions[1],"Edit resized widgets "+route+edge)
    const origin=canvas.mapToItem(surface,0,0)
    check(popup.y+popup.height<=origin.y+1,"controls overlap widget canvas "+route+edge)
    check(popup.x>=0 && popup.y>=0 && popup.x+popup.width<=surface.width && popup.y+popup.height<=surface.height,"editor outside output")
    check(liquid.participants.dashboardEditor?.inputBounds.width>0,"editor lacks native field input")
    check(liquid.records.some(r=>r.content.width===popup.width && r.content.height===popup.height),"editor lacks shared field paint")
    canvas.setWidgetVisible("notes",false);wait(50)
    check(canvas.canUndo && canvas.visibleIds.length===0 && popup.visible,"empty dashboard lost controls")
    clickAction(popup,"dashboardEditUndo");wait(50)
    check(canvas.visibleIds.includes("notes"),"Undo did not restore module")
    canvas.setWidgetVisible("notes",false);clickAction(popup,"dashboardEditCancel");wait(50)
    check(!canvas.editMode && JSON.stringify(Config.options.dashboard.canvas.widgets)===saved,"Cancel changed saved layout")
    canvas.beginEditMode();wait(80);canvas.setWidgetVisible("notes",false);clickAction(popup,"dashboardEditDone");wait(80)
    check(!canvas.editMode && !canvas.visibleIds.includes("notes"),"Done did not save layout")
    check(!popup.visible && liquid.participants.dashboardEditor?.inputBounds.width===0,"editor did not release input")
    count++
   }
   console.info("DASHBOARD_FIELD_PASS",count,"composed routes/edges/sizes: dimensions above-field Add Undo Cancel Done input-release")
  }catch(e){console.error("DASHBOARD_FIELD_FAIL",e.message,e.stack)}Qt.quit()}
 }
 Timer {interval:100;running:true;onTriggered:test.runChecks()}
}
''')
 with private_wayland(folder) as env:
  if env is None:print("SKIP: Dashboard field requires private Niri");raise SystemExit(0)
  config=folder/"config/illogical-impulse";config.mkdir(parents=True,exist_ok=True)
  value=json.loads((ROOT/"defaults/config.json").read_text());value["panelFamily"]="abyss";value["abyss"]["companion"]["enabled"]=False
  (config/"config.json").write_text(json.dumps(value));env["QSG_RHI_BACKEND"]="opengl"
  result=run_qs(folder,env,timeout=50)
  if result.returncode or "DASHBOARD_FIELD_PASS" not in result.stdout or any(s in result.stdout for s in ["DASHBOARD_FIELD_FAIL","ReferenceError:","TypeError:","Binding loop","Failed to load configuration"]):print(result.stdout);raise SystemExit(1)
  print("DASHBOARD_FIELD_PASS 16 composed route/edge/size cases; stable workspace; native Undo Cancel Done; field paint/input")
