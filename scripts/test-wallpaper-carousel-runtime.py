#!/usr/bin/env python3
"""Private native carousel and liquid texture-priming regression."""
from pathlib import Path
import json,os,shutil,tempfile,subprocess
from native_test_session import private_wayland,run_qs
ROOT=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='hadalis-wallpaper-carousel-') as name:
 folder=Path(name)
 (folder/"wallpapers").mkdir()
 for entry in ['modules','services','GlobalStates.qml','qmldir','assets','scripts','defaults','translations']:(folder/entry).symlink_to(ROOT/entry)
 for name,color in [('a','#156c9c'),('b','#bb4c8c'),('c','#249b75'),('d','#ac7e22'),('e','#7c59b4')]:
  subprocess.run(['magick','-size','320x180','xc:'+color,str(folder/'wallpapers'/(name+'.png'))],check=True)
 odd=folder/"quoted ' $HOME `false`.png"
 subprocess.run(['magick','-size','64x64','xc:#334455',str(odd)],check=True)
 (folder/'shell.qml').write_text(r'''
import QtQuick
import QtTest
import Quickshell
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.wallpaperLauncher
import qs.services
Window {
 id:root;visible:true;width:980;height:680;color:"#111820"
 Component.onCompleted:Quickshell.watchFiles=false
 property string prefix:"file://"+Quickshell.env("WALLPAPER_FIXTURES")+"/"
 property int starts:0
 property int finishes:0
 property int presentedPrime:0
 WallpaperLauncherContent {id:picker;width:parent.width;height:300;monitorName:"fixture-output";browseFolder:Quickshell.env("WALLPAPER_FIXTURES")}
 WallpaperCrossfader {
  id:wall;x:80;y:380;width:820;height:260;sourceSize:Qt.size(820,260)
  transitionType:"inirMelt";transitionBaseDuration:350
  onTransitionStarted:root.starts++
  onTransitionFinished:root.finishes++
 }
 ThumbnailImage {id:quoted;visible:false;sourcePath:Quickshell.env("QUOTED_IMAGE");generateThumbnail:true;sourceSize:Qt.size(64,64)}
 // Read the counter before performSwitch resets it by observing presented frames.
 Connections {target:root;function onFrameSwapped(){if(wall._shaderTexturePrimePending)root.presentedPrime++}}
 TestCase {
  id:test;when:false;optional:true
  function check(value,message){if(!value)throw new Error(message)}
  function named(item,name){if(item.objectName===name)return item;for(const child of item.data ?? item.children ?? []){const value=named(child,name);if(value)return value}return null}
  function allImages(item){let result=[];if(item.objectName==="wallpaperCardImage")result.push(item);for(const child of item.data ?? item.children ?? [])result=result.concat(allImages(child));return result}
  function runChecks(){try {
   tryCompare(Config,"ready",true,4000)
   Config.setNestedValues({"background.transition.type":"inirMelt","background.transition.enable":true})
   check(!AwwwBackend.enabled,"liquid mode has two wallpaper owners")
   GlobalStates.wallpaperLauncherOpen=true
   tryVerify(()=>picker.count===5,7000)
   check(picker.displayMode==="static" && picker.entries.length===5,"library lost image files")
   const search=named(picker,"wallpaperSearch"),carousel=named(picker,"wallpaperCarousel")
   search.text="b";tryCompare(picker,"count",1,2000)
   check(picker.selectedPath.endsWith('/b.png'),"search did not select the matching wallpaper")
   search.text="";tryCompare(picker,"count",5,2000);wait(80)
   picker.moveSelection(1);wait(230);check(carousel.currentIndex===1,"carousel navigation lost selection")
   tryVerify(()=>allImages(carousel).length>=5 && allImages(carousel).every(image=>image.status===Image.Ready),7000)
   tryCompare(quoted,"status",Image.Ready,7000)
   check(FileUtils.trimFileProtocol(named(carousel,"wallpaperCardImage").thumbnailPath).startsWith(Quickshell.env("XDG_CACHE_HOME")),"thumbnail escaped the private cache")
   wait(260)
   root.contentItem.grabToImage(result=>result.saveToFile(Quickshell.env("WALLPAPER_CAPTURE")))
   wall.source=root.prefix+"a.png";tryCompare(wall,"ready",true,3000)
   tryVerify(()=>!wall.transitionBusy,3000)
   const count=root.starts
   wall.source=root.prefix+"b.png"
   tryVerify(()=>wall._shaderTexturePrimePending || wall._transitioning,3000)
   tryVerify(()=>root.starts>count,3000)
   check(root.presentedPrime>=2,"liquid switch did not wait for presented texture frames")
   tryVerify(()=>!wall.transitionBusy,3000)
   check(wall.ready,"wallpaper disappeared at transition end")
   wall.source=root.prefix+"a.png";wait(25);wall.source=root.prefix+"c.png"
   tryVerify(()=>!wall.transitionBusy,4000)
   check(wall.ready && String(wall.data.find(c=>c.activeIndex!==undefined)?.displayedSource ?? '').endsWith('/c.png'),"rapid source changes did not coalesce to the final image")
   wall.enableTransitions=false;wall.source=root.prefix+"b.png";wait(80)
   check(!wall._transitioning,"disabled motion still rendered a liquid transition")
   console.info("WALLPAPER_CAROUSEL_PASS native-library search navigation single-owner presented-frame-prime rapid-switch reduced-motion")
  }catch(e){console.error("WALLPAPER_CAROUSEL_FAIL",e.message,e.stack)}Qt.quit()}
 }
 Timer {interval:100;running:true;onTriggered:test.runChecks()}
}
''')
 with private_wayland(folder) as env:
  if env is None:print('SKIP: wallpaper native test requires private Niri');raise SystemExit(0)
  config=folder/'config/illogical-impulse';config.mkdir(parents=True,exist_ok=True)
  data=json.loads((ROOT/'defaults/config.json').read_text());data.setdefault('wallpapers',{})['directory']=str(folder/'wallpapers');(config/'config.json').write_text(json.dumps(data))
  env.update(WALLPAPER_FIXTURES=str(folder/"wallpapers"),QUOTED_IMAGE=str(odd),WALLPAPER_CAPTURE='/tmp/hadalis-wallpaper-carousel-20261007.png',QSG_RHI_BACKEND='opengl')
  result=run_qs(folder,env,timeout=40);output=result.stdout
  if result.returncode or 'WALLPAPER_CAROUSEL_PASS' not in output or any(e in output for e in ['WALLPAPER_CAROUSEL_FAIL','ReferenceError:','TypeError:','Unable to assign','Binding loop','Failed to load configuration']):print(output);raise SystemExit(1)
  for line in output.splitlines():
   if 'WALLPAPER_CAROUSEL_PASS' in line:print(line)
