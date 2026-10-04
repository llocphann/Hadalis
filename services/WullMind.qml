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
    readonly property var downloadedModel: LocalModels.modelFor(model)
    readonly property var selectableModels: LocalModels.models.map(m=>({name:m.id,label:m.name,size:m.size})).concat(models)
    property var history: []
    property bool historyLoaded: false
    property bool historyHasMore: false
    property bool historyLoadingOlder: false
    property bool historyClearPending: false
    property var journal: ({schedule:[],mood:"",energy:"",journalPath:""})
    property var reminded: []
    property double epoch: 0
    property var pending: null
    property double startedAt: Date.now()
    property double lastContext: 0
    property double lastCheckIn: 0
    property string userMood: ""
    property string userEnergy: ""
    property string checkInStage: ""
    property string checkInDate: ""
    property double lastPlayful: Date.now()
    property int playfulIndex: -1
    readonly property bool available: aiEnabled && model.length>0 && (connectionStatus==="ready"
        || (downloadedModel && LocalModels.runtimePath.length>0))
    signal reactionRequested(string expression)
    signal historyPrepended(int count)

    function payload(action): var {
        const todo=Config.options?.todo?.obsidian ?? ({})
        return {action:action,endpoint:endpoint,model:model,
            modelPath:downloadedModel?.path ?? "",runtimePath:LocalModels.runtimePath,
            vault:obsidianEnabled ? String(todo.vaultPath || Config.options?.notes?.zettelkasten?.vaultPath || "") : "",
            referenceVault:obsidianEnabled ? String(options.referenceVault ?? "") : "",
            dailyFolder:String(todo.dailyNote?.folder ?? "00_Capture/01_Journal"),
            dailyFormat:String(todo.dailyNote?.format ?? "YYYY/MMMM/DD-MM-YYYY-dddd"),
            plannerHeading:String(todo.dailyNote?.plannerHeading ?? "Day Planner"),
            todoNotePath:String(todo.notePath ?? ""),
            shareObsidian:obsidianEnabled}
    }
    function cancel(): void {
        const cancelledChat=pending?.action==="chat" && !pending?.automatic
        epoch++;pending=null;busy=false;deadline.stop()
        if (cancelledChat) history=history.filter(entry=>entry?.pending!==true)
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
    function testConnection(): bool {
        LocalModels.ensureInitialized()
        if(downloadedModel){connectionStatus=LocalModels.runtimePath ? "available" : "runtime-unavailable";return true}
        return dispatch("probe")
    }
    function selectDownloaded(): void {
        if(!aiEnabled || model || !LocalModels.models.length)return
        const preferred=LocalModels.models.find(m=>m.name.toLowerCase().includes("qwen")) ?? LocalModels.models[0]
        Config.setNestedValue("abyss.companionMind.model",preferred.id)
    }
    function refreshJournal(automatic = false): bool {return dispatch("context",null,automatic)}
    function say(value, from = "built-in"): void {
        if (!talkEnabled || !String(value).trim()) return
        text=String(value).slice(0,420);source=from
        expiry.interval=conversationOpen ? 120000 : 18000;expiry.restart()
    }
    function oldestHistoryId(): double {
        for (const entry of history) {
            const id=Number(entry?.id ?? 0)
            if (id>0) return id
        }
        return 0
    }
    function loadHistory(older = false): bool {
        if (busy || draining || worker.running) return false
        const before=older ? oldestHistoryId() : 0
        if (older && (!historyLoaded || !historyHasMore || before<=0)) return false
        historyLoadingOlder=older
        if (!dispatch("history",{limit:60,beforeId:before})) {
            historyLoadingOlder=false
            return false
        }
        return true
    }
    function openChat(): void {
        if (!talkEnabled) return
        checkInStage=""
        conversationOpen=true;expiry.stop();text=""
        if (!historyLoaded) loadHistory(false)
    }
    function closeChat(): void {conversationOpen=false;expiry.interval=18000;expiry.restart()}
    function dismiss(): void {conversationOpen=false;checkInStage="";text="";expiry.stop();if(pending?.automatic) cancel()}
    function clearConversation(): void {
        cancel();history=[];historyLoaded=true;historyHasMore=false;text="";userMood="";userEnergy=""
        historyClearPending=true;historyClearRetry.restart()
    }
    function resolvePendingUser(id = 0, failed = false): void {
        const items=history.slice()
        for(let i=items.length-1;i>=0;i--) {
            if(items[i]?.role==="user" && items[i]?.pending===true) {
                items[i]=Object.assign({},items[i],{id:id||items[i].id,pending:false,failed:failed})
                history=items
                return
            }
        }
    }
    function sendMessage(message): bool {
        const prompt=String(message).trim().slice(0,1200)
        if (!prompt) return false
        if (!aiEnabled || !model) {
            const offline="My local model is taking a nap. Choose one in Companion > AI, then we can chat!"
            history=history.concat([{id:0,role:"user",content:prompt,ephemeral:true},
                {id:0,role:"assistant",content:offline,ephemeral:true}]).slice(-2000)
            historyLoaded=true;say(offline,"built-in")
            return true
        }
        if (historyClearPending) return false
        const accepted=dispatch("chat",{prompt:prompt,history:history.slice(-12),persistHistory:true})
        if (accepted) {
            history=history.concat([{id:0,role:"user",content:prompt,pending:true}]).slice(-2000)
            historyLoaded=true
        }
        return accepted
    }
    function today(): string {
        const now=new Date()
        return now.getFullYear()+"-"+String(now.getMonth()+1).padStart(2,"0")+"-"+String(now.getDate()).padStart(2,"0")
    }
    function askCheckIn(field = "mood"): void {
        if (busy || !talkEnabled) return
        conversationOpen=false;checkInDate=today();checkInStage=field
        say(field==="energy" ? "And how's your energy? Tiny spark or full splash?" : "Tiny check-in! How are you feeling today?")
        expiry.interval=45000;expiry.restart()
    }
    function choiceSaved(field, value): void {
        if (field==="mood") userMood=value
        else userEnergy=value
        journal=Object.assign({},journal,{[field]:value})
        if (checkInStage!==field) return
        if (field==="mood") askCheckIn("energy")
        else {
            checkInStage="";lastCheckIn=Date.now()
            say("Noted, little human. I'll bring the bubbles; you bring you!")
            reactionRequested("happy")
        }
    }
    function setCheckInChoice(field, value): bool {
        const values = field === "mood" ? ["terrible", "bad", "okay", "good", "great"]
            : field === "energy" ? ["drained", "low", "medium", "high", "peak"] : []
        if (!values.includes(value) || field!==checkInStage || busy) return false
        if (obsidianEnabled) return dispatch("check_in",{field:field,value:value,date:checkInDate})
        choiceSaved(field,value)
        return true
    }
    function openJournal(): void {
        if (journal.journalPath) Quickshell.execDetached(["xdg-open",journal.journalPath])
    }
    function offerAutomatic(): void {
        if (!hostVisible || !hostIdle || !idleMonitor.isIdle || !talkEnabled || proactive!=="occasional"
                || conversationOpen || busy || Date.now()-startedAt<90000 || text) return
        if (obsidianEnabled && Date.now()-lastContext>120000) {refreshJournal(true);return}
        const now=new Date(),minute=now.getHours()*60+now.getMinutes()
        const todayDate=today(),rows=(journal.schedule ?? []).slice()
        if(obsidianEnabled) {
            for(const task of (Todo.list ?? []).slice(0,128)) {
                if(task.done || task.sourceDate!==todayDate || !/^\d{1,2}:\d{2}$/.test(task.startTime ?? ""))continue
                const time=task.startTime.split(":");rows.push({start:Number(time[0])*60+Number(time[1]),title:String(task.content).slice(0,180),kind:"task"})
            }
            for(const event of CalendarSync.getEventsForDate(now).slice(0,32)) {
                if(event.allDay)continue
                const start=new Date(event.startDate)
                if(Number.isFinite(start.getTime()))rows.push({start:start.getHours()*60+start.getMinutes(),title:String(event.summary ?? event.title ?? "").slice(0,180),kind:"agenda"})
            }
        }
        rows.sort((a,b)=>a.start-b.start)
        const next=rows.find(s=>s.start>=minute-10 && s.start-minute<=10
            && !reminded.includes(todayDate+":"+s.start+":"+s.title))
        const key=next ? todayDate+":"+next.start+":"+next.title : ""
        if (next && !reminded.includes(key)) {
            reminded=reminded.slice(-31).concat([key])
            const cheer=next.kind==="calisthenics" ? "Time for calisthenics! Tiny arms cheering for yours."
                : next.kind==="cardio" ? "Cardio time! You run; I'll provide emotional splashes."
                : "Psst! "+next.title
            say(cheer+" · "+String(Math.floor(next.start/60)).padStart(2,"0")+":"+String(next.start%60).padStart(2,"0"),"schedule")
            reactionRequested("happy")
        } else if (Date.now()-lastCheckIn>2400000) {
            lastCheckIn=Date.now()
            askCheckIn("mood")
        } else if (Date.now()-lastPlayful>1200000) {
            lastPlayful=Date.now()
            const lines=["I tried counting my bubbles. One escaped. Suspicious.",
                "Important announcement: I am approximately one sip tall.",
                "If I sit very still, do I become a puddle with opinions?",
                "My cardio today: three laps around this tiny corner.",
                "I have two feet and absolutely no shoes budget.",
                "Your cursor looks busy. Mine would probably just be a fish.",
                "I asked the edge for advice. It said: go with the flow.",
                "Tiny water break? I mean you. I'm already excellent at being water."]
            playfulIndex=(playfulIndex+1+Math.floor(Math.random()*(lines.length-1)))%lines.length
            if(available)dispatch("chat",{prompt:"Make one cute silly observation as a tiny water droplet. No questions, reminders or claims about my activity.",history:[]},true)
            else say(lines[playfulIndex])
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
            if (job.action==="history") {
                historyLoaded=true;historyHasMore=false;historyLoadingOlder=false
                return
            }
            if (job.action==="history_clear") {
                historyClearPending=false
                return
            }
            if (job.action==="probe" || job.action==="chat") connectionStatus="error"
            if (job.action==="check_in") say("I couldn't save that to your journal. "+errorMessage)
            if (job.action==="chat" && !job.automatic) {
                const failure="My local model couldn't answer just now. We can try again in a little bit."
                resolvePendingUser(0,true)
                history=history.concat([{id:0,role:"assistant",content:failure,ephemeral:true}]).slice(-2000)
                say(failure,"built-in")
            }
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
        } else if (job.action==="history") {
            const incoming=(result.messages ?? [])
            if (Number(job.request.beforeId ?? 0)>0) {
                const existing=new Set(history.map(entry=>Number(entry?.id ?? 0)).filter(id=>id>0))
                const older=incoming.filter(entry=>!existing.has(Number(entry?.id ?? 0)))
                history=older.concat(history).slice(-2000)
                historyHasMore=result.hasMore===true;historyLoaded=true;historyLoadingOlder=false
                if (older.length) historyPrepended(older.length)
            } else {
                history=incoming.slice(-2000);historyHasMore=result.hasMore===true;historyLoaded=true;historyLoadingOlder=false
            }
        } else if (job.action==="history_clear") {
            historyClearPending=false;history=[];historyLoaded=true;historyHasMore=false
        } else if (job.action==="context") {
            journal=result;lastContext=Date.now()
            if (job.automatic) Qt.callLater(root.offerAutomatic)
        } else if (job.action==="check_in") {
            if(result.saved===true && result.date===checkInDate) {
                journal=Object.assign({},journal,{journalPath:result.journalPath,date:result.date})
                choiceSaved(result.field,result.value)
            }
        } else if (job.action==="chat") {
            connectionStatus="ready";historyLoaded=true
            if (!job.automatic) {
                resolvePendingUser(result.userMessageId ?? 0,false)
                history=history.concat([{id:result.assistantMessageId ?? 0,role:"assistant",content:result.text,
                    persisted:result.historySaved===true}]).slice(-2000)
            }
            say(result.text,"local")
            if (hostVisible) reactionRequested(result.expression)
        }
    }
    onAiEnabledChanged: {cancel();connectionStatus="disconnected";if(aiEnabled){LocalModels.ensureInitialized();selectDownloaded()}}
    onEndpointChanged: {cancel();models=[];connectionStatus="disconnected"}
    onModelChanged: {cancel();connectionStatus=downloadedModel ? LocalModels.runtimePath ? "available" : "runtime-unavailable"
        : models.some(m=>m.name===model) ? "ready" : "disconnected"}
    Component.onCompleted: if(aiEnabled)LocalModels.ensureInitialized()
    Connections {target:LocalModels;function onUpdated():void{root.selectDownloaded()}}
    onContextKeyChanged: {if(pending) cancel();journal=({schedule:[],mood:"",energy:"",journalPath:""});lastContext=0}
    onProactiveChanged: if(proactive!=="occasional" && pending?.automatic)cancel()
    onHostVisibleChanged: if (!hostVisible) {if(pending?.automatic) cancel();if(!conversationOpen){text="";checkInStage=""}}
    onHostIdleChanged: if(!hostIdle && pending?.automatic)cancel()
    onTalkEnabledChanged: if(!talkEnabled) {cancel();dismiss()}
    IdleMonitor {id:idleMonitor;enabled:root.hostVisible && root.talkEnabled && root.proactive==="occasional";timeout:60;respectInhibitors:true}
    Timer {interval:60000;repeat:true;running:root.hostVisible && root.hostIdle && root.talkEnabled
        && root.proactive==="occasional" && idleMonitor.isIdle && !root.conversationOpen;onTriggered:root.offerAutomatic()}
    Timer {id:expiry;repeat:false;onTriggered:if(!root.conversationOpen){root.text="";root.checkInStage=""}}
    Timer {id:deadline;interval:35000;repeat:false;onTriggered:{root.cancel();root.errorMessage="Local model request timed out.";root.connectionStatus="error"}}
    Timer {id:historyClearRetry;interval:100;repeat:false;onTriggered:{
        if(!root.historyClearPending)return
        if(root.draining || worker.running || historyClearWorker.running){restart();return}
        historyClearWorker.startObserved=false
        historyClearWorker.running=true
    }}
    Process {
        id:historyClearWorker
        running:false;stdinEnabled:true
        property bool startObserved:false
        command:["/usr/bin/python3",Quickshell.shellPath("scripts/wull/local_mind.py")]
        stdout:StdioCollector {id:historyClearReply}
        onStarted:{
            startObserved=true
            write(JSON.stringify(root.payload("history_clear"))+"\n")
        }
        onRunningChanged:if(!running && !startObserved && root.historyClearPending) {
            root.historyClearPending=false
            root.errorMessage="Wull chat history could not be cleared."
        }
        onExited:(code,status)=>{
            let cleared=false
            try {
                const envelope=JSON.parse(String(historyClearReply.text ?? ""))
                cleared=code===0 && envelope.ok===true && envelope.result?.cleared===true
            } catch(e) {}
            startObserved=false
            root.historyClearPending=false
            if(!cleared)root.errorMessage="Wull chat history could not be cleared."
        }
    }
    Process {
        id:worker
        running:false;stdinEnabled:true
        property bool startObserved:false
        property double serial:0
        command:["/usr/bin/python3",Quickshell.shellPath("scripts/wull/local_mind.py")]
        stdout:StdioCollector {id:reply}
        onStarted:{worker.startObserved=true;worker.serial=root.pending?.serial ?? -1;if(root.pending)worker.write(JSON.stringify(root.pending.request)+"\n");deadline.interval=root.pending?.request?.modelPath ? 80000 : 35000;deadline.restart()}
        onRunningChanged:if(!running && !startObserved && root.pending)root.completed("",-1,root.pending.serial)
        onExited:(code,status)=>{
            if(root.draining){root.draining=false;return}
            root.completed(String(reply.text ?? ""),code,worker.serial)
        }
    }
}
