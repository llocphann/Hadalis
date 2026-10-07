#!/usr/bin/env python3
"""Native field-contour mask on all edges and Dock; no rectangular water cut."""
import json,tempfile
from pathlib import Path
from PIL import Image
from native_test_session import private_wayland,run_qs
ROOT=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='hadalis-wull-immersion-') as name:
 folder=Path(name)
 for entry in ['modules','services','GlobalStates.qml','qmldir','assets','scripts','defaults','translations']:(folder/entry).symlink_to(ROOT/entry)
 (folder/'shell.qml').write_text(r'''
import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import qs.modules.common
import qs.modules.abyss.looks
import qs.modules.abyss.companion
Window {
 id:root;visible:true;width:800;height:600;color:"#111820"
 Component.onCompleted:Quickshell.watchFiles=false
 Rectangle {anchors.fill:parent;z:-2;color:"#111820"}
 property string edge:"dock"
 property var point:edge==="dock" ? ({x:400,y:400,nx:0,ny:-1,scale:1}) : edge==="bottom" ? ({x:400,y:root.height-20,nx:0,ny:-1,scale:1}) : edge==="top" ? ({x:400,y:20,nx:0,ny:1,scale:1}) : edge==="left" ? ({x:20,y:300,nx:1,ny:0,scale:1}) : ({x:root.width-20,y:300,nx:-1,ny:0,scale:1})
 QtObject {
  id:presence;property bool permitted:true;property bool grounded:false
  property var placement:({contact:root.point})
  signal waterInteraction(var point,string action)
 }
 Item {
  id:body;width:112;height:98
  x:root.point.x-56;y:root.point.y-98
  property bool motionEnabled:true;property bool effectsEnabled:true
  property real presentation:.5;property bool leaving:true;property string hideClip:"sink"
  Rectangle {x:-48;y:-100;width:208;height:298;color:"#ff0000"}
 }
 WullAbyssLink {id:link;presence:presence;actor:body;allowed:true}
 AbyssField {
  id:field;anchors.fill:parent;z:-1;edgeInsets:({left:20,top:20,right:20,bottom:20});waterLink:link
  records:root.edge==="dock" ? [{surface:{x:160,y:400,width:480,height:100}}] : []
 }
 Loader {
  id:mask;active:true;z:3;width:208;height:298;x:body.x-48;y:body.y-100;sourceComponent:field.immersionComponent
  Binding {target:mask.item;property:"bodyItem";value:body;when:!!mask.item}
  Binding {target:mask.item;property:"renderRect";value:Qt.vector4d(mask.x,mask.y,mask.width,mask.height);when:!!mask.item}
 }
 AbyssCompanion {id:actual;visible:false;presentationManaged:true;motionEnabled:true;effectsEnabled:true;character:"aqua";upright:true;connectedWater:true;hideClip:"sink"}
 TestCase {
  id:test;when:false;optional:true
  property bool saved:false
  function check(value,message){if(!value)throw new Error(message)}
  function capture(item,name){saved=false;item.grabToImage(result=>{saved=result.saveToFile(Quickshell.env("OUT")+"/"+name+".png")});tryCompare(test,"saved",true,2000)}
  function runChecks(){try {
   tryCompare(Config,"ready",true,4000)
   Config.setNestedValues({"panelFamily":"abyss","abyss.quality":"quality"})
   tryCompare(field,"ready",true,4000)
   for(const edge of ["dock","bottom","top","left","right"]){
    root.edge=edge;wait(150)
    check(mask.item && mask.item.status!==ShaderEffect.Error,"field mask failed to render")
    capture(mask.item,edge)
    const n=root.point
    console.info("IMMERSION_RECT",edge,JSON.stringify({x:mask.x,y:mask.y,point:n}))
   }
   mask.active=false;wait(80);check(mask.item===null,"idle retained a body capture")
   root.edge="dock";body.visible=false;link.actor=actual
   actual.edge="bottom";actual.emergenceEdge="bottom";actual.activeEmergenceEdge="bottom"
   actual.x=344;actual.y=302;actual.hideClip="pulled";actual.presentation=.5;actual.leaving=true;actual.reveal=0;actual.curvedImmersion=true;actual.visible=true
   check(actual.emergenceNormal>.1,"actual Aqua fixture did not enter the water")
   mask.active=true;wait(150);mask.item.bodyItem=actual;wait(150)
   capture(root.contentItem,"actual-dock")
   console.info("WULL_IMMERSION_NATIVE_PASS shared-field contour four-edges dock finite-capture")
  }catch(e){console.error("WULL_IMMERSION_NATIVE_FAIL",e.message,e.stack)}Qt.quit()}
 }
 Timer {interval:100;running:true;onTriggered:test.runChecks()}
}
''')
 with private_wayland(folder) as env:
  if env is None:print('SKIP: native Wull immersion requires private Niri');raise SystemExit(0)
  conf=folder/'config/illogical-impulse';conf.mkdir(parents=True,exist_ok=True)
  value=json.loads((ROOT/'defaults/config.json').read_text());value['panelFamily']='abyss';(conf/'config.json').write_text(json.dumps(value))
  env['OUT']=str(folder)
  result=run_qs(folder,env,timeout=25);output=result.stdout
  if result.returncode or 'WULL_IMMERSION_NATIVE_PASS' not in output or any(e in output for e in ['WULL_IMMERSION_NATIVE_FAIL','ReferenceError:','TypeError:','Unable to assign','Binding loop','Failed to load configuration']):print(output);raise SystemExit(1)
  rects={}
  for line in output.splitlines():
   if 'IMMERSION_RECT ' in line:
    edge,data=line.split('IMMERSION_RECT ',1)[1].split(' ',1);rects[edge]=json.loads(data)
  for edge,rect in rects.items():
   image=Image.open(folder/(edge+'.png')).convert('RGBA');point=rect['point']
   def alpha(depth,tangent=0):
    x=round(point['x']+point['nx']*depth-point['ny']*tangent-rect['x']);y=round(point['y']+point['ny']*depth+point['nx']*tangent-rect['y'])
    assert 0<=x<image.width and 0<=y<image.height,(edge,x,y)
    return image.getpixel((x,y))[3]
   assert alpha(26)>245,(edge,'workspace unexpectedly cropped')
   assert alpha(-26)<5,(edge,'submerged body leaked through the field')
   assert alpha(-7)>200,(edge,'old rectangular water cut remained')
   assert alpha(-7,60)<40,(edge,'curved quicksand contour became a rectangle')
  assert len(rects)==5
  # Only an owned fixture is captured; this is visual evidence, not desktop acceptance.
  target=Path('/tmp/hadalis-wull-quicksand-20261007.png');target.write_bytes((folder/'actual-dock.png').read_bytes())
  print('WULL_IMMERSION_NATIVE_PASS pixel workspace/water curved contour all four edges and Dock; capture destroyed at rest')
