import QtQuick
import QtTest
import Quickshell
import qs.services
import qs.services.ai
import qs.modules.common

Window {
    id:root;visible:true;width:640;height:350;color:"#051521"
    TestCase {
        id:input;when:false;optional:true
        function check(value,message):void {if(!value)throw new Error(message)}
        function runChecks():void {
            try {
                tryCompare(Config,"ready",true,4000)
                Ai._initialized=true;AiProviderCatalog.initialized=true
                Config.setNestedValues({"policies.ai":2,"abyss.companionMind.aiEnabled":true,
                    "abyss.companionMind.model":"","abyss.companionMind.proactive":"manual"})
                LocalModels.ensureInitialized()
                tryVerify(()=>LocalModels.models.length===1,4000)
                const local=LocalModels.models[0]
                check(local.id.startsWith("gguf:") && !!LocalModels.runtimePath,"downloaded GGUF/runtime not discovered")
                Ai.syncDownloadedModels()
                check(Ai.modelList.includes(local.id) && Ai.models[local.id].local && Ai.models[local.id].api_format==="gguf","AI catalog did not adopt downloaded model")
                check(Ai.setModel(local.id,false,false),"local model selection rejected")
                check(Ai.sendUserMessage("Hello local model!"),"AI local request rejected")
                tryCompare(Ai,"busy",false,6000)
                tryVerify(()=>Ai.messageIDs.length===2 && Ai.messageByID[Ai.messageIDs[1]].done,6000)
                check(Ai.messageIDs.length===2 && new Set(Ai.messageIDs).size===2,"local assistant appeared twice")
                check(Ai.messageByID[Ai.messageIDs[1]].content==="Tiny fixture reply.","AI local reply not presented")
                WullMind.hostVisible=true;WullMind.hostIdle=true
                WullMind.selectDownloaded();wait(50)
                check(WullMind.model===local.id && WullMind.available,"Wull did not adopt downloaded model")
                check(WullMind.sendMessage("Hello Wull!"),"Wull GGUF request rejected")
                tryCompare(WullMind,"busy",false,6000)
                check(WullMind.source==="local" && WullMind.text==="Splish!" && WullMind.history.length===2,"Wull local reply did not survive process boundary")
                console.log("WULL_GGUF_UI=PASS localInventory aiCatalog aiSelection singleAssistant sharedSupervisor wullAutomaticSelection wullJSONReply")
            } catch(e){console.error("WULL_GGUF_UI=FAIL "+e)}
            shutdown.start()
        }
    }
    Timer {interval:150;running:true;onTriggered:input.runChecks()}
    Timer {id:shutdown;interval:150;onTriggered:Qt.quit()}
}
