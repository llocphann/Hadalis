#!/usr/bin/env python3
"""Capture only an owned nested output at the first Qt host frame."""
import re,tempfile
from pathlib import Path
from PIL import Image
from native_test_session import private_wayland,run_qs
ROOT=Path(__file__).resolve().parents[1]
# Native and Quickshell window declarations from the repaired active fixtures.
samples=[('Window','scripts/test-wull-collapsed-bar.py'),('FloatingWindow','scripts/test-notification-settings-runtime.py')]
with tempfile.TemporaryDirectory(prefix='hadalis-debug-first-frame-') as name:
 folder=Path(name)
 with private_wayland(folder) as env:
  if env is None:print('SKIP: first-frame debug canvas requires private Niri');raise SystemExit(0)
  for kind,path in samples:
   source=(ROOT/path).read_text();header=re.search(r'\b'+kind+r'\s*\{([\s\S]{0,220})',source).group(1)
   color=re.search(r'\bcolor\s*:\s*("[^"]+")',header).group(1)
   screenshot=folder/(kind+'.png')
   (folder/'shell.qml').write_text('''
import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
ShellRoot {
 id:root;property int frames:0
 HOST {id:host;visible:true;WIDTH:600;HEIGHT:420;color:COLOR}
 Connections {
  target:host.contentItem.Window.window
  function onFrameSwapped(){
   root.frames++
   if(root.frames===1){shot.command=["niri","msg","action","screenshot-screen","--show-pointer","false","--path",Quickshell.env("SHOT")];shot.running=true}
  }
 }
 Process {id:shot;onExited:(code,status)=>{if(code===0)console.info("DEBUG_FIRST_FRAME_PASS",root.frames);else console.error("DEBUG_FIRST_FRAME_FAIL",code);Qt.quit()}}
 Timer {interval:8000;running:true;onTriggered:{console.error("DEBUG_FIRST_FRAME_FAIL deadline");Qt.quit()}}
}
'''.replace('HOST',kind).replace('WIDTH','implicitWidth' if kind=='FloatingWindow' else 'width').replace('HEIGHT','implicitHeight' if kind=='FloatingWindow' else 'height').replace('COLOR',color))
   result=run_qs(folder,dict(env,SHOT=str(screenshot)),timeout=12)
   assert result.returncode==0 and 'DEBUG_FIRST_FRAME_PASS' in result.stdout and 'DEBUG_FIRST_FRAME_FAIL' not in result.stdout,result.stdout
   assert screenshot.is_file(),'first presented frame was not captured'
   image=Image.open(screenshot).convert('RGB');pixels=list(image.getdata())
   white=sum(min(pixel)>220 for pixel in pixels)
   assert white/len(pixels)<.01,(kind,'white first-frame canvas',white/len(pixels))
   center=image.getpixel((image.width//2,image.height//2));assert max(center)<80,(kind,'bright initial Qt clear',center)
   print(f'DEBUG_FIRST_FRAME_PASS {kind} actual first-frame request; owned nested output white fraction {white/len(pixels):.4f}')
