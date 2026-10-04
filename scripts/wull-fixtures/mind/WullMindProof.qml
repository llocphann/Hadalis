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
                    "abyss.companionMind.endpoint":Quickshell.env("WULL_TEST_ENDPOINT"),"abyss.companionMind.model":"tiny:local"})
                wait(80)
                WullMind.hostVisible=true;WullMind.hostIdle=true
                check(!WullMind.busy && WullMind.history.length===0,"opening Settings started inference")
                WullMind.say("Tiny check-in! How are your mood and energy today?","built-in");wait(80)
                check(cloud.visible && !cloud.editing && !WullMind.conversationOpen,"automatic talk stole conversation focus")
                const field=root.named(cloud,"wullChatInput"),background=root.named(cloud,"wullCloudBackground")
                mouseMove(root.contentItem,20,720);wait(80)
                check(!cloud.controlsVisible && !field.visible && !field.activeFocus,"idle speech exposed input")
                check(background.border.width===0 && field.placeholderText==="","speech retained border or input hint")
                check(!root.named(settings,"wullReferenceVault"),"removed reference-vault control remains")
                const collapsedHeight=cloud.height
                mouseMove(cloud,cloud.width/2,14);wait(100)
                check(cloud.controlsVisible && field.visible && !field.activeFocus && !WullMind.conversationOpen,"hover did not expose input without focus")
                check(cloud.height>collapsedHeight,"hover did not expand the speech cloud")
                check(WullMind.testConnection(),"probe rejected")
                tryCompare(WullMind,"busy",false,6000)
                check(WullMind.connectionStatus==="ready" && WullMind.models.length===1,"local probe not ready")
                WullMind.openChat();mouseMove(cloud,cloud.width/2,14);wait(100)
                check(cloud.editing,"explicit chat did not open editor")
                field.text="Hello Wull!"
                mouseClick(root.named(cloud,"wullChatSend"));wait(20)
                check(field.text==="","icon send did not submit the input")
                tryCompare(WullMind,"busy",false,6000)
                check(WullMind.source==="local" && WullMind.text.indexOf("Splish!")===0 && WullMind.history.length===2,"local reply not presented")
                WullMind.clearConversation();check(WullMind.history.length===0,"clear retained history")
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
                mouseMove(cloud,cloud.width/2,14);wait(80)
                mouseClick(root.named(cloud,"wullmood-good"));wait(30)
                check(WullMind.userMood==="good" && WullMind.userEnergy==="","mood button invented an energy value")
                mouseClick(root.named(cloud,"wullenergy-high"));wait(30)
                check(WullMind.userMood==="good" && WullMind.userEnergy==="high","Obsidian-style choice buttons did not set the session")
                check(root.named(cloud,"wullmood-good").toggled && root.named(cloud,"wullenergy-high").toggled,"chosen values lack selected state")
                check(!WullMind.setCheckInChoice("energy","anything"),"invalid choice accepted")
                field.text="saved draft"
                mouseMove(root.contentItem,20,720);wait(80)
                check(!cloud.controlsVisible && !field.visible && !field.activeFocus && !WullMind.conversationOpen,"hover leave retained input or focus")
                check(field.text==="saved draft","hover leave lost the draft")
                check(root.outsideClicks===0,"speech controls counted as nearby disturbance")
                mouseClick(root.contentItem,20,720);wait(30)
                check(root.outsideClicks===1,"speech guard blocked clicks outside the cloud")
                WullMind.dismiss();check(!cloud.visible,"dismiss retained speech input")
                console.log("WULL_MIND=PASS actualProcess localProbe EnglishReply borderlessCloud hoverInput noHoverFocus iconSend moodEnergyButtons retainedDraft boundedHistory cancel staleReply invalidEndpoint offlineMessage settingsAI noReferenceVault")
            } catch(e) {console.error("WULL_MIND=FAIL "+e)}
            shutdown.start()
        }
    }
    Timer {interval:200;running:Config.ready;onTriggered:input.runChecks()}
    Timer {id:shutdown;interval:150;onTriggered:Qt.quit()}
}
