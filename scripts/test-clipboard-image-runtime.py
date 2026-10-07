#!/usr/bin/env python3
"""Native image decode/layout and reused-delegate regression; private cache only."""
from pathlib import Path
import os, shutil, struct, subprocess, tempfile, zlib

ROOT=Path(__file__).resolve().parents[1]
if not shutil.which("qs"):
    print("SKIP: native clipboard images require Quickshell")
    raise SystemExit(0)

def png(width,height):
    def chunk(kind,data):
        return struct.pack(">I",len(data))+kind+data+struct.pack(">I",zlib.crc32(kind+data)&0xffffffff)
    scan=(b"\0"+bytes([35,170,220,255])*width)*height
    return b"\x89PNG\r\n\x1a\n"+chunk(b"IHDR",struct.pack(">IIBBBBB",width,height,8,6,0,0,0))+chunk(b"IDAT",zlib.compress(scan))+chunk(b"IEND",b"")

with tempfile.TemporaryDirectory(prefix="hadalis-clipboard-image-") as name:
    folder=Path(name)
    for entry in ["modules","services","GlobalStates.qml","qmldir","assets","scripts","defaults","translations"]:
        (folder/entry).symlink_to(ROOT/entry)
    config=folder/"config/illogical-impulse";config.mkdir(parents=True)
    shutil.copy(ROOT/"defaults/config.json",config/"config.json")
    (folder/"one.png").write_bytes(png(200,80))
    (folder/"two.png").write_bytes(png(64,128))
    fake=folder/"cliphist-native-fixture"
    fake.write_text("#!/usr/bin/python3\nimport pathlib,sys,time\nroot=pathlib.Path(__file__).parent\nif len(sys.argv)>2 and sys.argv[1]=='decode':\n if sys.argv[2]=='3': time.sleep(.35)\n sys.stdout.buffer.write((root/('one.png' if sys.argv[2] in ('1','3') else 'two.png')).read_bytes())\n")
    fake.chmod(0o755)
    (folder/"shell.qml").write_text(r'''
import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.services.deferred
ShellRoot {
 id:root
 property int step:0
 property int ticks:0
 function check(ok,message): bool {
  if(ok)return true
  console.error("CLIPBOARD_IMAGE_FAIL",message);Qt.quit();return false
 }
 FloatingWindow {
  visible:true;implicitWidth:400;implicitHeight:250;color:"#111820"
  CliphistImage {
   id:preview
   anchors.centerIn:parent
   width:implicitWidth;height:implicitHeight
   maxWidth:160;maxHeight:100
   imageDecodePath:Quickshell.env("CLIPBOARD_IMAGE_CACHE")
  }
 }
 Timer {
  interval:80;repeat:true;running:true
  onTriggered:{
   if(++root.ticks>80){root.check(false,"decode did not settle");return}
   if(!Config.ready)return
   const image=preview.children.find(child=>child.objectName==="clipboardDecodedImage")
   if(root.step===0){
    Cliphist.cliphistBinary=Quickshell.env("CLIPBOARD_IMAGE_DECODER")
    preview.entry="1\t[[ binary data png 200 × 80 ]]";root.step++
   }else if(root.step===1 && image.status===Image.Ready){
    if(!root.check(image.implicitWidth===200 && preview.width===160 && Math.abs(preview.height-64)<.1,"spaced Unicode dimensions decode and display at bounded size"))return
    preview.entry="2\t[[ binary data image/png ]]";root.step++
   }else if(root.step===2 && image.status===Image.Ready && String(preview.source).endsWith('/2')){
    if(!root.check(image.implicitWidth===64 && image.implicitHeight===128 && preview.width>0 && preview.height===100,"dimensionless metadata uses decoded intrinsic pixels"))return
    preview.entry="3\t[[ binary data png 200x80 ]]";root.step++
   }else if(root.step===3){
    preview.entry="2\t[[ binary data png ]]";root.step++
   }else if(root.step===4 && image.status===Image.Ready && String(preview.source).endsWith('/2')){
    if(!root.check(image.implicitWidth===64 && preview.width<=160 && preview.height<=100,"reused delegate never publishes a stale image"))return
    console.info("CLIPBOARD_IMAGE_PASS native-binary Unicode-metadata intrinsic-size delegate-reuse bounded-preview")
    Qt.quit()
   }
  }
 }
}
''')
    env=dict(os.environ,QT_QPA_PLATFORM="offscreen",QSG_RHI_BACKEND="software",
        XDG_CONFIG_HOME=str(folder/"config"),XDG_STATE_HOME=str(folder/"state"),XDG_CACHE_HOME=str(folder/"cache"),
        CLIPBOARD_IMAGE_CACHE=str(folder/"images"),CLIPBOARD_IMAGE_DECODER=str(fake))
    for key in ["QS_CONFIG_NAME","QS_CONFIG_PATH","QS_MANIFEST"]:env.pop(key,None)
    result=subprocess.run(["dbus-run-session","--","qs","-p",str(folder),"--no-color"],env=env,text=True,capture_output=True,timeout=15)
    output=result.stdout+result.stderr
    bad=["CLIPBOARD_IMAGE_FAIL","ReferenceError:","TypeError:","Binding loop","Unable to assign","is not a type","unavailable"]
    if result.returncode or "CLIPBOARD_IMAGE_PASS" not in output or any(word in output for word in bad):
        print(output);raise SystemExit(1)
    for line in output.splitlines():
        if "CLIPBOARD_IMAGE_PASS" in line:print(line)
