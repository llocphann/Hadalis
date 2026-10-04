pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.modules.common

// On-demand model I/O is isolated from the renderer/native companion clock.
Singleton {
    id: root
    readonly property var options: Config.options?.abyss?.companionMind ?? ({})
    readonly property bool aiEnabled: options.aiEnabled === true
    readonly property bool talkEnabled: options.talkEnabled ?? true
    readonly property bool obsidianEnabled: options.obsidianEnabled === true
    readonly property string endpoint: String(options.endpoint ?? "http://127.0.0.1:11434")
    readonly property string model: String(options.model ?? "")
    readonly property string referenceVault: String(options.referenceVault ?? "")
    readonly property string proactive: String(options.proactive ?? "occasional")
    readonly property string contextKey: JSON.stringify([obsidianEnabled, referenceVault,
        Config.options?.todo?.obsidian ?? {}, Config.options?.notes?.zettelkasten?.vaultPath ?? ""])
    property bool hostVisible: false
    property bool hostIdle: false
    property string text: ""
    property string source: "built-in"
    property bool conversationOpen: false
    property bool busy: false
    property bool draining: false
    property string connectionStatus: "disconnected"
    property string errorMessage: ""
    property var models: []
    property var history: []
    property var journal: ({schedule:[],mood:"",energy:"",journalPath:""})
    property var reminded: []
    property double epoch: 0
    property var pending: null
    property double startedAt: Date.now()
    property double lastContext: 0
    property double lastCheckIn: 0
    property string userMood: ""
    property string userEnergy: ""
    readonly property bool available: aiEnabled && model.length>0 && connectionStatus==="ready"
    signal reactionRequested(string expression)

    function payload(action): var {
        const todo=Config.options?.todo?.obsidian ?? ({})
        return {action:action,endpoint:endpoint,model:model,
            vault:obsidianEnabled ? String(todo.vaultPath || Config.options?.notes?.zettelkasten?.vaultPath || "") : "",
            referenceVault:obsidianEnabled ? String(options.referenceVault ?? "") : "",
            dailyFolder:String(todo.dailyNote?.folder ?? "00_Capture/01_Journal"),
            dailyFormat:String(todo.dailyNote?.format ?? "YYYY/MMMM/DD-MM-YYYY-dddd"),
            plannerHeading:String(todo.dailyNote?.plannerHeading ?? "Day Planner"),
            shareObsidian:obsidianEnabled}
    }
    function cancel(): void {
        epoch++;pending=null;busy=false;deadline.stop()
        if (worker.running) {draining=true;worker.running=false}
        if (connectionStatus==="generating" || connectionStatus==="connecting") connectionStatus="disconnected"
    }
    function dispatch(action, extra = null, automatic = false): bool {
        if (busy || draining || worker.running || (automatic && (!hostVisible || !hostIdle || conversationOpen))) return false
        if (action==="chat" && !aiEnabled) return false
        const request=Object.assign(payload(action),extra ?? {})
        const serial=++epoch
        pending={serial:serial,action:action,request:request,automatic:automatic}
        busy=true;errorMessage=""
        if (action==="chat") connectionStatus="generating"
        else if (action==="probe") connectionStatus="connecting"
        worker.startObserved=false;worker.running=true
        return true
    }
    function testConnection(): bool {return dispatch("probe")}
    function refreshJournal(automatic = false): bool {return dispatch("context",null,automatic)}
    function say(value, from = "built-in"): void {
        if (!talkEnabled || !String(value).trim()) return
        text=String(value).slice(0,420);source=from
        expiry.interval=conversationOpen ? 120000 : 18000;expiry.restart()
    }
    function openChat(): void {
        if (!talkEnabled) return
        conversationOpen=true;expiry.stop()
        if (!text) say("Hi hi! How are your mood and energy today?", "built-in")
    }
    function closeChat(): void {conversationOpen=false;expiry.interval=18000;expiry.restart()}
    function dismiss(): void {conversationOpen=false;text="";expiry.stop();if(pending?.automatic) cancel()}
    function clearConversation(): void {cancel();history=[];text="";userMood="";userEnergy=""}
    function sendMessage(message): bool {
        const prompt=String(message).trim().slice(0,1200)
        if (!prompt) return false
        if (!aiEnabled || !model) {
            say("My local model is taking a nap. Choose one in Companion > AI, then we can chat!", "built-in")
            return false
        }
        return dispatch("chat",{prompt:prompt,history:history})
    }
    function checkIn(mood, energy): void {
        userMood=String(mood).slice(0,40);userEnergy=String(energy).slice(0,40)
        lastCheckIn=Date.now()
        if (available) dispatch("chat",{prompt:"My mood is "+userMood+" and my energy is "+userEnergy+". Give me a tiny friendly check-in.",history:history})
        else say("Thank you for telling me! I'll keep you a little company.","built-in")
    }
    function openJournal(): void {
        if (journal.journalPath) Quickshell.execDetached(["xdg-open",journal.journalPath])
    }
    function offerAutomatic(): void {
        if (!hostVisible || !hostIdle || !idleMonitor.isIdle || !talkEnabled || proactive!=="occasional"
                || conversationOpen || busy || Date.now()-startedAt<90000 || text) return
        if (obsidianEnabled && Date.now()-lastContext>120000) {refreshJournal(true);return}
        const now=new Date(),minute=now.getHours()*60+now.getMinutes()
        const next=(journal.schedule ?? []).find(s=>s.start>=minute && s.start-minute<=10)
        const key=next ? journal.date+":"+next.start+":"+next.title : ""
        if (next && !reminded.includes(key)) {
            reminded=reminded.slice(-31).concat([key])
            say("Psst! "+next.title+" starts at "+String(Math.floor(next.start/60)).padStart(2,"0")+":"+String(next.start%60).padStart(2,"0")+". I'll cheer you on!","schedule")
            reactionRequested("happy")
        } else if (Date.now()-lastCheckIn>2400000) {
            lastCheckIn=Date.now()
            if (available) dispatch("chat",{prompt:"Ask gently about my mood and energy today. One cute short question, in English.",history:[]},true)
            else say("Tiny check-in! How are your mood and energy today?","built-in")
        }
    }
    function completed(raw, exitCode, serial = epoch): void {
        const job=pending
        if (!job || job.serial!==epoch || serial!==job.serial) return
        pending=null;busy=false;deadline.stop()
        if (job.automatic && (!hostVisible || !hostIdle || conversationOpen || proactive!=="occasional")) {
            if (connectionStatus==="generating") connectionStatus="disconnected"
            return
        }
        let envelope
        try {if(raw.length>32768 || exitCode!==0) throw new Error();envelope=JSON.parse(raw)}
        catch(e) {envelope={ok:false,error:{message:"Wull's local helper did not return a valid reply."}}}
        if (!envelope.ok) {
            errorMessage=String(envelope.error?.message ?? "Local model is unavailable.")
            if (job.action!=="context") connectionStatus="error"
            if (job.action==="chat" && !job.automatic) say("My local model couldn't answer just now. We can try again in a little bit.","built-in")
            return
        }
        const result=envelope.result
        if (job.action==="probe") {
            models=result.models ?? []
            if (!model && models.length) {
                const installed=models.slice().sort((a,b)=>a.size-b.size)
                Config.setNestedValue("abyss.companionMind.model",installed[0].name)
            }
            connectionStatus=models.some(m=>m.name===model) || (!model && models.length) ? "ready" : "model-unavailable"
        } else if (job.action==="context") {
            journal=result;lastContext=Date.now()
            if (job.automatic) Qt.callLater(root.offerAutomatic)
        } else if (job.action==="chat") {
            connectionStatus="ready"
            history=history.slice(-4).concat([{role:"user",content:job.request.prompt},{role:"assistant",content:result.text}])
            say(result.text,"local")
            if (hostVisible) reactionRequested(result.expression)
        }
    }
    onAiEnabledChanged: {cancel();connectionStatus="disconnected"}
    onEndpointChanged: {cancel();models=[];connectionStatus="disconnected"}
    onModelChanged: {cancel();connectionStatus=models.some(m=>m.name===model) ? "ready" : "disconnected"}
    onContextKeyChanged: {if(pending) cancel();journal=({schedule:[],mood:"",energy:"",journalPath:""});lastContext=0}
    onProactiveChanged: if(proactive!=="occasional" && pending?.automatic)cancel()
    onHostVisibleChanged: if (!hostVisible) {if(pending?.automatic) cancel();if(!conversationOpen)text=""}
    onHostIdleChanged: if(!hostIdle && pending?.automatic)cancel()
    onTalkEnabledChanged: if(!talkEnabled) {cancel();dismiss()}
    IdleMonitor {id:idleMonitor;enabled:root.hostVisible && root.talkEnabled && root.proactive==="occasional";timeout:60;respectInhibitors:true}
    Timer {interval:60000;repeat:true;running:root.hostVisible && root.hostIdle && root.talkEnabled
        && root.proactive==="occasional" && idleMonitor.isIdle && !root.conversationOpen;onTriggered:root.offerAutomatic()}
    Timer {id:expiry;repeat:false;onTriggered:if(!root.conversationOpen)root.text=""}
    Timer {id:deadline;interval:35000;repeat:false;onTriggered:{root.cancel();root.errorMessage="Local model request timed out.";root.connectionStatus="error"}}
    Process {
        id:worker
        running:false;stdinEnabled:true
        property bool startObserved:false
        property double serial:0
        command:["/usr/bin/python3",Quickshell.shellPath("scripts/wull/local_mind.py")]
        stdout:StdioCollector {id:reply}
        onStarted:{worker.startObserved=true;worker.serial=root.pending?.serial ?? -1;if(root.pending)worker.write(JSON.stringify(root.pending.request)+"\n");deadline.restart()}
        onRunningChanged:if(!running && !startObserved && root.pending)root.completed("",-1,root.pending.serial)
        onExited:(code,status)=>{
            if(root.draining){root.draining=false;return}
            root.completed(String(reply.text ?? ""),code,worker.serial)
        }
    }
}
