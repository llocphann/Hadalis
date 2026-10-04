import QtQuick
import QtTest
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.settings
import qs.modules.abyss.companion
Window {
    id:root;visible:true;width:900;height:750;color:"#061521"
    property int outsideClicks: 0
    PointHandler {
        parent:root.contentItem
        onActiveChanged: if(active && !cloud.containsScenePoint(point.scenePosition)) root.outsideClicks++
    }
    function named(item,name) {
        if(item.objectName===name)return item
        for(const child of item.data ?? item.children ?? []){const match=named(child,name);if(match)return match}
        return null
    }
    AbyssCompanion {id:actor;x:570;y:550;reveal:1;motionEnabled:false;upright:true;interactive:true}
    WullTalkCloud {id:cloud;actor:actor;outputWidth:root.width;outputHeight:root.height;allowed:true}
    CompanionConfig {id:settings;visible:false;width:800;height:700;activeSection:"ai"}
    TestCase {
        id:input;when:false;optional:true
        function check(value,message):void {if(!value)throw new Error(message)}
        function runChecks():void {
            try {
                tryCompare(Config,"ready",true,4000)
                Config.setNestedValues({"abyss.companionMind.aiEnabled":true,"abyss.companionMind.proactive":"manual",
                    "abyss.companionMind.endpoint":Quickshell.env("WULL_TEST_ENDPOINT"),"abyss.companionMind.model":"tiny:local",
                    "abyss.companionMind.obsidianEnabled":false})
                wait(80)
                const syntheticNow=new Date(2026,9,5,9,0,0)
                const reminderRows=WullMind.reminderRows(syntheticNow,
                    [{done:false,sourceDate:"2026-10-05",startTime:"09:05",content:"Todo reminder"}],
                    [{allDay:false,startDate:new Date(2026,9,5,9,7,0),summary:"Agenda reminder"}])
                check(reminderRows.some(row=>row.kind==="task" && row.title==="Todo reminder")
                    && reminderRows.some(row=>row.kind==="agenda" && row.title==="Agenda reminder"),
                    "Todo/Agenda reminders incorrectly require Obsidian")
                WullMind.hostVisible=true;WullMind.hostIdle=true
                check(!WullMind.busy && WullMind.history.length===0,"opening Settings started inference")
                WullMind.askCheckIn("mood");wait(80)
                check(cloud.visible && !cloud.editing && !WullMind.conversationOpen,"automatic talk stole conversation focus")
                const field=root.named(cloud,"wullChatInput"),background=root.named(cloud,"wullCloudBackground")
                mouseMove(root.contentItem,20,720);wait(80)
                check(cloud.controlsVisible && !field.visible && !field.activeFocus,"automatic check-in exposed input")
                check(background.border.width===0 && field.placeholderText==="","speech retained border or input hint")
                check(!root.named(settings,"wullReferenceVault"),"removed reference-vault control remains")
                const collapsedHeight=cloud.height
                mouseMove(cloud,cloud.width/2,14);wait(100)
                check(cloud.controlsVisible && !field.visible && !field.activeFocus && !WullMind.conversationOpen,"check-in hover exposed prompt input")
                check(root.named(cloud,"wullmood-good").visible && !root.named(cloud,"wullenergy-high").visible,"check-in showed two rows")
                check(cloud.height===collapsedHeight,"check-in changed size while answering")
                check(WullMind.testConnection(),"probe rejected")
                tryCompare(WullMind,"busy",false,6000)
                check(WullMind.connectionStatus==="ready" && WullMind.models.length===1,"local probe not ready")
                mouseMove(root.contentItem,20,720);WullMind.openChat();wait(100)
                check(cloud.editing,"explicit chat did not open editor")
                tryCompare(WullMind,"busy",false,3000)
                field.text="Hello Wull!"
                keyClick(Qt.Key_Return);wait(20)
                check(field.text==="","Enter did not submit the input")
                check(!!root.named(cloud,"wullChatSend") && !!root.named(cloud,"wullChatHistory")
                    && !root.named(cloud,"wullMessageSource") && !root.named(cloud,"wullCloudDismiss"),
                    "quick chat did not retain exactly the send control")
                tryCompare(WullMind,"busy",false,6000)
                check(WullMind.source==="local" && WullMind.text.indexOf("Splish!")===0 && WullMind.history.length===2
                    && WullMind.history[0].role==="user" && WullMind.history[1].role==="assistant",
                    "local reply/history not presented")
                WullMind.closeChat();WullMind.history=[];WullMind.historyLoaded=false;WullMind.openChat()
                tryCompare(WullMind,"busy",false,3000)
                check(WullMind.history.length===2 && WullMind.history[0].role==="user"
                    && WullMind.history[1].role==="assistant","persisted quick-chat history did not reload")
                WullMind.closeChat();WullMind.conversationIdleTimeout=160;WullMind.openChat();wait(260)
                check(!WullMind.conversationOpen,"idle quick chat kept proactive reminders blocked")
                WullMind.conversationIdleTimeout=120000
                WullMind.clearConversation();check(WullMind.history.length===0,"clear retained history")
                tryCompare(WullMind,"historyClearPending",false,3000);tryCompare(WullMind,"busy",false,3000)
                check(WullMind.sendMessage("slow reply"),"cancellation request rejected")
                wait(45);const stale=WullMind.epoch;WullMind.cancel()
                WullMind.completed(JSON.stringify({ok:true,result:{text:"STALE",expression:"happy"}}),0,stale)
                check(WullMind.text!=="STALE" && WullMind.history.length===0,"stale reply applied after cancellation")
                tryVerify(()=>!WullMind.draining,3000)
                Config.setNestedValue("abyss.companionMind.endpoint","http://127.0.0.1:0");wait(50)
                check(WullMind.testConnection(),"invalid endpoint probe not dispatched")
                tryCompare(WullMind,"busy",false,4000)
                check(WullMind.connectionStatus==="error" && WullMind.errorMessage.length>0,"invalid local endpoint looked ready")
                Config.setNestedValue("abyss.companionMind.aiEnabled",false);wait(40)
                WullMind.clearConversation();WullMind.openChat();WullMind.sendMessage("Hi!")
                check(WullMind.source==="built-in" && !WullMind.busy && WullMind.text.indexOf("local model")>=0,"offline companion pretended inference")
                WullMind.dismiss()
                Config.setNestedValues({"abyss.companionMind.obsidianEnabled":true,"todo.obsidian.vaultPath":Quickshell.env("WULL_TEST_VAULT")});wait(80)
                check(WullMind.obsidianEnabled && WullMind.payload("check_in").vault===Quickshell.env("WULL_TEST_VAULT"),"journal bridge did not adopt configured vault "+JSON.stringify({enabled:WullMind.obsidianEnabled,vault:WullMind.payload("check_in").vault}))
                WullMind.askCheckIn("mood")
                mouseMove(cloud,cloud.width/2,14);wait(80)
                mouseClick(root.named(cloud,"wullmood-good"));wait(30)
                tryCompare(WullMind,"busy",false,6000)
                check(WullMind.userMood==="good" && WullMind.userEnergy==="",
                    "mood save/session mismatch "+JSON.stringify({mood:WullMind.userMood,energy:WullMind.userEnergy,
                        stage:WullMind.checkInStage,busy:WullMind.busy,pending:WullMind.pending?.action ?? ""}))
                check(WullMind.checkInStage==="energy" && !root.named(cloud,"wullmood-good").visible
                    && root.named(cloud,"wullenergy-high").visible && !field.visible,"next question did not show energy alone")
                mouseMove(cloud,cloud.width/2,14);wait(50)
                mouseClick(root.named(cloud,"wullenergy-high"));wait(30)
                tryCompare(WullMind,"busy",false,6000)
                check(WullMind.userMood==="good" && WullMind.userEnergy==="high","Obsidian-style choice buttons did not set the session")
                check(WullMind.journal.journalPath.startsWith(Quickshell.env("WULL_TEST_VAULT")),"choices were not persisted through the helper")
                check(WullMind.checkInStage==="" && !root.named(cloud,"wullenergy-high").visible,"completed check-in retained choices")
                check(!WullMind.setCheckInChoice("energy","anything"),"invalid choice accepted")
                field.text="saved draft"
                WullMind.openChat();wait(80)
                mouseMove(root.contentItem,20,720);wait(80)
                check(cloud.editing && field.visible && WullMind.conversationOpen,"explicit chat closed when the pointer left")
                check(field.text==="saved draft","hover leave lost the draft")
                keyClick(Qt.Key_Escape);wait(40)
                check(!cloud.visible && !WullMind.conversationOpen,"Escape did not close chat")
                check(root.outsideClicks===0,"speech controls counted as nearby disturbance")
                mouseClick(root.contentItem,20,720);wait(30)
                check(root.outsideClicks===1,"speech guard blocked clicks outside the cloud")
                WullMind.dismiss();check(!cloud.visible,"dismiss retained speech input")
                console.log("WULL_MIND=PASS actualProcess localProbe EnglishReply borderlessCloud noCheckInInput separateQuestions journalWrites explicitChatFocus enterSend sendOnlyControl persistentHistory reminderSources idleChatRelease retainedDraft escapeClose boundedHistory cancel staleReply invalidEndpoint offlineMessage settingsAI noReferenceVault")
            } catch(e) {console.error("WULL_MIND=FAIL "+e)}
            shutdown.start()
        }
    }
    Timer {interval:200;running:Config.ready;onTriggered:input.runChecks()}
    Timer {id:shutdown;interval:150;onTriggered:Qt.quit()}
}
