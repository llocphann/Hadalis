pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id:root
    property var models:[]
    property string runtimePath:""
    property string error:""
    property bool initialized:false
    readonly property bool refreshing:scan.running
    signal updated()
    function ensureInitialized(): void {if(!initialized){initialized=true;refresh()}}
    function refresh(): void {if(!scan.running)scan.running=true}
    function modelFor(id): var {return models.find(m=>m.id===id) ?? null}
    Timer {id:scanDeadline;interval:5000;onTriggered:{scan.running=false;root.error="Local model discovery timed out."}}
    Process {
        id:scan
        command:["/usr/bin/python3",Quickshell.shellPath("scripts/ai/local_models.py")]
        onStarted:scanDeadline.restart()
        stdout:StdioCollector {id:result}
        onExited:(code,status)=>{
            scanDeadline.stop()
            try {
                if(code!==0 || result.text.length>65536)throw new Error()
                const found=JSON.parse(result.text)
                root.models=(found.models ?? []).slice(0,32);root.runtimePath=found.runtimePath ?? ""
                root.error=found.error ?? ""
            } catch(e){root.error="Local model discovery failed."}
            root.updated()
        }
    }
}
