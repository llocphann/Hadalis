#!/usr/bin/env python3
"""Real pointer transfer for StyledPopup hosted by the existing Abyss field."""
import json
import tempfile
from pathlib import Path
from native_test_session import private_wayland, run_qs

ROOT = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="hadalis-popup-hover-") as name:
    folder = Path(name)
    for entry in ["modules", "services", "GlobalStates.qml", "qmldir", "assets", "scripts", "defaults", "translations"]:
        (folder / entry).symlink_to(ROOT / entry)
    (folder / "shell.qml").write_text(r'''
pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import Quickshell
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.bar
import qs.modules.abyss
import qs.modules.abyss.content
ShellRoot {
 id: root
 property int frames: 0
 property int clicks: 0
 property int idleCloses: 0
 property int genericCloses: 0
 property bool barRevealed: true
 property string edge: "bottom"
 QtObject { id: trigger; property bool triggerHovered: true }
 Component.onCompleted: Quickshell.watchFiles=false
 AbyssSurfaceController {
  id: controller
  presentationItem: scene
  outputWidth: scene.width; outputHeight: scene.height
  // Production clearanceInsets includes the source module's inward depth.
  edgeInsets: ({left:root.edge==="left" ? 40 : 8,right:root.edge==="right" ? 40 : 8,
     top:root.edge==="top" ? 40 : 8,bottom:root.edge==="bottom" ? 40 : 8})
 }
 FloatingWindow {
  id: window; visible:true; implicitWidth:640; implicitHeight:360; color:"#111820"
  Item {
   id: scene; anchors.fill:parent
   Item {
    id: anchor
    x: root.edge==="left" ? 8 : root.edge==="right" ? scene.width-40 : 160
    y: root.edge==="top" ? 8 : root.edge==="bottom" ? scene.height-40 : 160
    width: root.edge==="left" || root.edge==="right" ? 32 : 80
    height: root.edge==="left" || root.edge==="right" ? 80 : 32
    property var liquidController: controller
    property string attachedEdge: root.edge
    property string kind: "clock"
    visible: root.barRevealed || GlobalStates.barPopupHoverHeld(window.screen.name)
    MouseArea { anchors.fill:parent; hoverEnabled:true; onClicked:root.clicks++ }
   }
   AbyssBodyHost {
    id: host; anchors.fill:parent
    readonly property var popupEntry: controller.popupSlots[0]
    readonly property var hostedPopup: popupEntry?.popup ?? null
    identity:"styledPopup0"; controller:controller; edge:root.edge
    includeEdgeConnection:true
    open:hostedPopup?.presentationActive ?? false
    externalProgress:hostedPopup?.revealProgress ?? 0
    embeddedItem:hostedPopup?.contentItem ?? null
    padding:14; span:root.edge==="left" || root.edge==="right" ? 128 : 208
    depth:root.edge==="left" || root.edge==="right" ? 208 : 128; along:136
    edgeInsets:controller.edgeInsets
    Component.onCompleted:controller.registerPopupHost(0,host)
    Component.onDestruction:controller.unregisterPopupHost(0,host)
    HoverHandler {
     parent:host.hoverParent; enabled:host.open
     onHoveredChanged:if(host.hostedPopup) host.hostedPopup._contentHovered=hovered
    }
   }
   AbyssGenericPopupPresenter {
    id: genericHost; anchors.fill:parent
    controller:controller;outputName:window.screen.name
    outputWidth:scene.width;outputHeight:scene.height
    presentationInsets:controller.edgeInsets
    requestedKind:"utilities";requestedOpen:false
    requestedFallbackEdge:root.edge;requestedAlongCenter:260
    onCloseRequested: { root.genericCloses++;requestedOpen=false }
   }
   AbyssPopupContent {
    id: generic; x:320; y:40; width:300; height:180
    kind:"launcher"; enabled:false; visible:enabled; participant:trigger; idleDismissDelay:150
    onCloseRequested: { root.idleCloses++;enabled=false }
    MaterialTextField { id: editor; visible:false; z:2; width:140; height:40; text:"fixture"; enableSettingsSearch:false }
   }
  }
 }
 StyledPopup {
  id: popup; hoverTarget:anchor
  Rectangle {
   implicitWidth:180; implicitHeight:100; color:"#29414b"
   MouseArea { anchors.fill:parent;hoverEnabled:true;onClicked:root.clicks++ }
  }
 }
 TestCase {
  id: test; when:false; optional:true
  function check(v,m) { if(!v) throw new Error(m) }
  function render() {
   const before=root.frames
   check(scene.grabToImage(image=>root.frames++),"frame request refused")
   tryVerify(()=>root.frames>before,2000)
   check(root.frames>before,"scene render deadline")
  }
  function outside() { mouseMove(scene,600,20);wait(160);render();root.barRevealed=true }
  function runChecks() { try {
   tryCompare(Config,"ready",true,4000)
   Config.setNestedValue("performance.reduceAnimations",true)
   Config.setNestedValue("bar.autoHide.enable",true)
   GlobalStates.deferredPanelsReady=true
   render();outside()
   check(!popup.requestedVisible,"popup starts open")
   for(const edge of ["bottom","top","left","right"]) {
    root.edge=edge;render();outside()
    mouseMove(anchor,anchor.width/2,anchor.height/2);wait(80);render()
    check(popup.requestedVisible && controller.activePopup===popup,"bare Item anchor did not open by hover on "+edge)
    check(popup.contentItem.parent===host.contentParent,"popup content was not hosted by the existing field")
    // This point lies on the drawn connector, outside both source and content.
    const content=host.record.content
    const ins=controller.edgeInsets
    const x=edge==="left" ? ins.left+6 : edge==="right" ? scene.width-ins.right-6 : content.x+content.width/2
    const y=edge==="top" ? ins.top+6 : edge==="bottom" ? scene.height-ins.bottom-6 : content.y+content.height/2
    const before=JSON.stringify({content,input:host.inputBounds,x,y,edge:host.edge})
    mouseMove(scene,x,y);wait(220);render()
    // The source hover timer expires after handoff. The actual output lease
    // must keep its auto-hide source visible while the pointer owns the popup.
    root.barRevealed=false
    check(popup.requestedVisible && popup._contentHovered,
       "dwelling on the visible "+edge+" connection closed the popup: "+before)
    mouseMove(host.contentParent,host.contentParent.width/2,host.contentParent.height/2);wait(900);render()
    check(popup.requestedVisible && popup._contentHovered,"anchor-to-popup handoff collapsed the popup")
    // Straight portions of the painted body include 14 px of padding around
    // the feature. Hovering those pixels must hold the same lease as content.
    const padPoints=[
     [content.x-7,content.y+content.height/2],
     [content.x+content.width+7,content.y+content.height/2],
     [content.x+content.width/2,content.y-7],
     [content.x+content.width/2,content.y+content.height+7]
    ]
    for(const point of padPoints){
     mouseMove(scene,point[0],point[1]);wait(900);render()
     check(popup.requestedVisible && popup._contentHovered,"painted popup padding dismissed owner on "+edge+": "+JSON.stringify({point,input:host.inputBounds,content:host.record.content,requested:popup.requestedVisible,hosted:host.hostedPopup!==null}))
     check(GlobalStates.barPopupHoverHeld(window.screen.name) && anchor.visible,"hovered popup let the Edgebar auto-hide")
    }
    outside()
    check(!popup.requestedVisible && !popup.presentationActive && controller.activePopup===null,"pointer exit left a stale popup lease")
    check(!GlobalStates.barPopupHoverHeld(window.screen.name),"final exit retained an auto-hide Bar lease")
   }
   root.edge="bottom";render();outside()
   mouseMove(anchor,40,16);wait(80);render()
   popup.dismissPresentation();wait(40)
   check(!popup.requestedVisible,"explicit dismissal failed")
   outside();mouseMove(anchor,40,16);wait(80);render()
   check(popup.requestedVisible,"dismissed hover popup could not reopen after leaving")
   anchor.enabled=false;wait(160);render()
   check(!popup.presentationActive,"disabled anchor retained a presentation lease")
   outside();anchor.enabled=true;popup.hoverActivates=false
   mouseMove(anchor,40,16);wait(120);render()
   check(!popup.requestedVisible,"click-only popup was opened by hover")
   popup.alternativeVisibleCondition=true;wait(80);render()
   check(popup.requestedVisible && controller.activePopup===popup,"explicit click-only request stopped working")
   popup.alternativeVisibleCondition=false;outside()
   check(!popup.presentationActive && root.clicks===0,"hover test clicked the trigger or leaked the popup")
   for(const edge of ["bottom","top","left","right"]){
    root.edge=edge;genericHost.hoverKind="utilities";genericHost.requestedOpen=true
    tryCompare(genericHost,"ready",true,4000);render()
    const feature=genericHost.contentItem.item
    const child=Qt.createQmlObject('import QtQuick; MouseArea { anchors.fill:parent;hoverEnabled:true;acceptedButtons:Qt.NoButton;z:10 }',feature)
    const c=genericHost.record.content,ins=controller.edgeInsets
    const points=[
     [edge==="left" ? ins.left+6 : edge==="right" ? scene.width-ins.right-6 : c.x+c.width/2,
      edge==="top" ? ins.top+6 : edge==="bottom" ? scene.height-ins.bottom-6 : c.y+c.height/2],
     [c.x+c.width/2,c.y+c.height/2],
     [c.x-7,c.y+c.height/2],[c.x+c.width+7,c.y+c.height/2],
     [c.x+c.width/2,c.y-7],[c.x+c.width/2,c.y+c.height+7]
    ]
    for(const point of points){
     mouseMove(scene,point[0],point[1]);genericHost.hoverKind="";wait(900);render()
     check(genericHost.requestedOpen && root.genericCloses===0,"generic body/bridge/padding idle timer closed a hovered popup on "+edge+": "+JSON.stringify(point))
    }
    child.destroy();mouseMove(scene,scene.width-10,scene.height/2);wait(900);render()
    check(!genericHost.requestedOpen,"generic popup did not close after final leave")
    check(root.genericCloses===1,"generic dismissal emitted more than once")
    root.genericCloses=0
   }
   generic.enabled=true;generic.forceActiveFocus();wait(40)
   check(generic.activeFocus,"focus fixture did not acquire Qt focus")
   trigger.triggerHovered=false;wait(400)
   check(root.idleCloses===1,"retained Qt focus left the hover popup stuck open after pointer exit")
   trigger.triggerHovered=true;generic.enabled=true;editor.visible=true
   editor.forceActiveFocus();wait(60)
   check(generic.editorFocusHeld,"editable text did not hold its own popup input session")
   trigger.triggerHovered=false;wait(400)
   check(root.idleCloses===1,"idle dismissal interrupted an editable text session")
   editor.readOnly=true;wait(400)
   check(root.idleCloses===2,"read-only text retained a stale input session")
   console.info("POPUP_ANCHOR_HOVER_PASS")
  } catch(e) { console.error("POPUP_ANCHOR_HOVER_FAIL",e.message,e.stack) } Qt.quit() }
 }
 Timer { interval:100;running:true;onTriggered:test.runChecks() }
}
''')
    with private_wayland(folder) as env:
        if env is None:
            raise SystemExit("SKIP: popup hover requires a private Niri surface")
        config = folder / "config/illogical-impulse"
        config.mkdir(parents=True, exist_ok=True)
        data = json.loads((ROOT / "defaults/config.json").read_text())
        data["panelFamily"] = "abyss"
        data["abyss"]["companion"]["enabled"] = False
        (config / "config.json").write_text(json.dumps(data))
        # Every grab retains its 2-second deadline; sustained body/padding dwell
        # must outlast actual hide timers even when nested Niri is unfocused.
        result = run_qs(folder, env, timeout=170)
        if result.returncode or "POPUP_ANCHOR_HOVER_PASS" not in result.stdout or any(
            token in result.stdout for token in ["POPUP_ANCHOR_HOVER_FAIL", "ReferenceError:", "TypeError:", "Binding loop", "Failed to load configuration"]
        ):
            print(result.stdout)
            raise SystemExit(1)
        print("POPUP_ANCHOR_HOVER_PASS four-edge sustained body/padding/bridge hover with interactive children, generic idle timers, auto-hide Bar hold/release, reentry and click-only/editor focus")
