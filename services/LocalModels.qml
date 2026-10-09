pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

Singleton {
    id:root
    property var models:[]
    property var checkpoints:[]
    property string runtimePath:""
    property string error:""
    property bool initialized:false
    property bool _refreshPending:false
    property string _scanFolder:""
    readonly property string modelFolder:String(Config.options?.ai?.localModelFolder ?? "").trim()
    readonly property bool refreshing:scan.running
    signal updated()
    function ensureInitialized(): void {if(!initialized){initialized=true;refresh()}}
    function refresh(): void {
        if(!Config.ready || scan.running){_refreshPending=true;return}
        _refreshPending=false
        _scanFolder=modelFolder
        scan.command=["/usr/bin/python3",Quickshell.shellPath("scripts/ai/local_models.py")]
            .concat(_scanFolder ? ["--extra-root",_scanFolder] : [])
        scan.running=true
    }
    onModelFolderChanged: {if(initialized)refresh()}
    Connections {
        target:Config
        function onReadyChanged():void{if(Config.ready && root.initialized)root.refresh()}
    }
    function modelFor(id): var {return models.find(m=>m.id===id) ?? null}
    Timer {id:scanDeadline;interval:5000;onTriggered:{scan.running=false;root.error="Local model discovery timed out."}}
    Process {
        id:scan
        onStarted:scanDeadline.restart()
        stdout:StdioCollector {id:result}
        onExited:(code,status)=>{
            scanDeadline.stop()
            if(root._refreshPending || root._scanFolder!==root.modelFolder){
                Qt.callLater(root.refresh)
                return
            }
            try {
                if(code!==0 || result.text.length>65536)throw new Error()
                const found=JSON.parse(result.text)
                if(!Array.isArray(found.models) || !Array.isArray(found.checkpoints ?? []))throw new Error()
                root.models=(found.models ?? []).slice(0,32);root.runtimePath=found.runtimePath ?? ""
                root.checkpoints=(found.checkpoints ?? []).slice(0,8)
                root.error=found.error ?? ""
            } catch(e){
                root.models=[];root.checkpoints=[];root.runtimePath=""
                root.error="Local model discovery failed."
            }
            root.updated()
        }
    }
}
