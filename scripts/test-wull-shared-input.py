#!/usr/bin/env python3
"""Actual shared Quickshell Regions and policy bindings, without native input."""
import os
from pathlib import Path
import re
import runpy
import signal
import subprocess
import tempfile

ROOT=Path(__file__).resolve().parents[1]
source=(ROOT/"modules/abyss/AbyssPerimeter.qml").read_text()
def block(marker):
    start=source.index(marker); opening=source.index("{",start); depth=1; end=opening+1
    while depth:
        depth+=(source[end]=="{")-(source[end]=="}");end+=1
    return source[start:end]
common=block("readonly property Region companionInputMask:")
utility=block("readonly property Region utilityInputMask:")
native=block("readonly property Region nativeInputMask:")
references=re.findall(r'Region\s*\{\s*regions:\s*\[window\.companionInputMask\]\s*\}',native)
assert len(references)==1
selection=re.search(r'^\s*mask:\s*(.*)$',source,re.MULTILINE).group(1)
qml='''
import QtQuick
import Quickshell
import "modules/abyss/companion/WullHostPolicy.js" as WullHostPolicy
ShellRoot {
    Item {
        id: window
        property bool presented: true
        property bool companionHostActive: true
        property bool overviewDragging: false
        QtObject {id:field;property bool ready:true}
        QtObject {id:liquid;property bool activeDialog:false}
        QtObject {id:utility;property bool open:false;property rect inputBounds:Qt.rect(240,360,400,180)}
        Item {id:emptyInput;width:0;height:0}
        Item {id:companion;x:80;y:220;width:112;height:98;property bool interactive:true;property bool inputReady:true}
        readonly property Region dragPassThrough: Region {}
        readonly property Region dialogInputMask: Region {x:420;y:160;width:280;height:240}
        @COMMON@
        @UTILITY@
        readonly property Region nativeInputMask: Region {@NATIVE@}
        property Region mask: @SELECTION@
        function check(value,message): void {
            if(!value){console.error("WULL_SHARED_INPUT=FAIL "+message);Qt.quit();throw new Error(message)}
        }
        function includes(region,target): bool {
            for(let i=0;i<region.regions.length;i++)
                if(region.regions[i]===target || includes(region.regions[i],target))return true
            return false
        }
        function run(): void {
            for(let selected=0;selected<2;selected++) {
                utility.open=!!selected
                check(mask===(selected ? utilityInputMask : nativeInputMask),"wrong owner mask")
                check(includes(mask,companionInputMask),"shared host absent from selected Region")
                for(let bits=0;bits<16;bits++) {
                    companionHostActive=!!(bits&1);companion.interactive=!!(bits&2)
                    companion.visible=!!(bits&4);companion.inputReady=!!(bits&8)
                    check(companionInputMask.item===(bits===15 ? companion : emptyInput),"host gate changed")
                }
            }
            const content=utilityInputMask.regions[0]
            check(content.x===240 && content.y===360 && content.width===400 && content.height===180,"utility bounds shifted")
            check(utilityInputMask.x===0 && utilityInputMask.y===0,"union offsets the shared host")
            field.ready=false;check(content.width===0,"unready utility captures input")
            field.ready=true;presented=false;check(content.width===0,"hidden utility captures input")
            liquid.activeDialog=true;check(mask===dialogInputMask && !includes(mask,companionInputMask),"dialog lost precedence")
            overviewDragging=true;check(mask===dragPassThrough && mask.regions.length===0,"overview drag no longer passes through")
            console.log("WULL_SHARED_INPUT=PASS "+JSON.stringify({realQuickshellRegions:true,productionBindings:true,
                nativeAndUtility:true,gateCases:32,utilityBounds:true,dialogAndOverviewPrecedence:true,nativeDesktopAcceptance:false}))
            Qt.callLater(Qt.quit)
        }
        Component.onCompleted:Qt.callLater(run)
    }
}
'''.replace("@COMMON@",common).replace("@UTILITY@",utility).replace("@NATIVE@",references[0]).replace("@SELECTION@",selection)
core=runpy.run_path(str(ROOT/"scripts/wull-manual-visual-matrix.py"))
with tempfile.TemporaryDirectory(prefix="wull-shared-input-") as temp:
    private=Path(temp);shell,xdg=core["staged"](private)
    (shell/"shell.qml").write_text(qml)
    env=core["private_env"](xdg,private/"result.json")
    env["QT_QUICK_BACKEND"]="software"
    with (private/"test.log").open("w") as output:
        process=subprocess.Popen(["dbus-run-session","--","qs","--path",str(shell/"shell.qml")],cwd=ROOT,
            env=env,stdin=subprocess.DEVNULL,stdout=output,stderr=subprocess.STDOUT,start_new_session=True)
        try:code=process.wait(timeout=15)
        except subprocess.TimeoutExpired:code=-1
        finally:
            if process.poll() is None:
                os.killpg(process.pid,signal.SIGTERM)
                try:process.wait(timeout=3)
                except subprocess.TimeoutExpired:os.killpg(process.pid,signal.SIGKILL);process.wait(timeout=3)
    log=(private/"test.log").read_text()
    bad=("WULL_SHARED_INPUT=FAIL","ReferenceError:","TypeError:","SyntaxError:","Unable to assign","Binding loop","Failed to load configuration","Quickshell has crashed","Quickshell has been restarted")
    if code or "WULL_SHARED_INPUT=PASS" not in log or any(value in log for value in bad):
        print(log);raise SystemExit("Actual shared Region binding check failed")
    for line in log.splitlines():
        if "WULL_SHARED_INPUT=PASS" in line:print(line.split("WULL_SHARED_INPUT=",1)[1])
