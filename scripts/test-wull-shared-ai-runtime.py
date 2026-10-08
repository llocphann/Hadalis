#!/usr/bin/env python3
"""Wull uses the real Ai service with a private loopback protocol fixture."""
from pathlib import Path
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json, os, shutil, subprocess, tempfile, threading, time
from native_test_session import private_wayland, run_qs

ROOT=Path(__file__).resolve().parents[1]
if not shutil.which("qs"):
    print("SKIP: Wull shared AI runtime requires Quickshell")
    raise SystemExit(0)
requests=[]
class Handler(BaseHTTPRequestHandler):
    def log_message(self,*args): pass
    def do_POST(self):
        data=json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        requests.append((self.path,data,dict(self.headers)))
        if self.path=="/slow":time.sleep(.7)
        failure=self.path=="/failure"
        self.send_response(429 if failure else 200)
        self.send_header("Content-Type","text/event-stream");self.end_headers()
        payload={"error":{"message":"fixture rate limit"}} if failure else {
            "choices":[{"delta":{"content":json.dumps({"text":"Fixture hello","expression":"happy"})},"finish_reason":"stop"}]}
        try:self.wfile.write(("data: "+json.dumps(payload)+"\n\ndata: [DONE]\n\n").encode())
        except (BrokenPipeError,ConnectionResetError):pass

server=ThreadingHTTPServer(("127.0.0.1",0),Handler)
threading.Thread(target=server.serve_forever,daemon=True).start()
try:
 with tempfile.TemporaryDirectory(prefix="hadalis-wull-ai-") as name:
    folder=Path(name)
    for entry in ["modules","services","GlobalStates.qml","qmldir","assets","scripts","defaults","translations"]:
        (folder/entry).symlink_to(ROOT/entry)
    config=folder/"config/illogical-impulse";config.mkdir(parents=True)
    shutil.copy(ROOT/"defaults/config.json",config/"config.json")
    (folder/"shell.qml").write_text(r'''
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.modules.common
import qs.services
import qs.services.deferred
ShellRoot {
 id:root
 Component.onCompleted: Quickshell.watchFiles=false
 property int step:0
 property int ticks:0
 property var mainIDs:[]
 function check(ok,message): bool {
  if(ok)return true
  console.error("WULL_SHARED_AI_FAIL",message);Qt.quit();return false
 }
 function add(id,path): void {
  Ai.addModel(id,{name:id,model:id,endpoint:Quickshell.env("AI_FIXTURE_URL")+path,
   local:true,requires_key:false,provider_id:"fixture",api_format:"openai",
   capabilities:{chat:"supported",reasoning:"supported"}})
 }
 FloatingWindow {visible:true;implicitWidth:360;implicitHeight:180;color:"#111820"}
 Timer {
  interval:100;running:true;repeat:true
  onTriggered:{
   if(++root.ticks>160){root.check(false,"requests did not settle");return}
   if(!Config.ready)return
   if(root.step===0){
    Ai._initialized=true
    const originalPrompt=Config.options.ai.systemPrompt
    const substitutions=Ai.promptSubstitutions
    Config.setNestedValue("ai.systemPrompt","{DISTRO}/{DISTRO}|{DATETIME}|{WINDOWCLASS}|{DE}|$& literal")
    if(!root.check(Ai.systemPrompt===substitutions["{DISTRO}"]+"/"+substitutions["{DISTRO}"]+"|"+substitutions["{DATETIME}"]+"|"+substitutions["{WINDOWCLASS}"]+"|"+substitutions["{DE}"]+"|$& literal","live repeated context substitutions preserve literal text"))return
    Config.setNestedValue("ai.systemPrompt","")
    if(!root.check(Ai.systemPrompt==="","clearing the AI prompt leaves an empty typed prompt"))return
    Config.setNestedValue("ai.systemPrompt",originalPrompt)
    KeyringStorage.keyringData=({apiKeys:{fixture:"fixture-credential"}});KeyringStorage.loaded=true
    root.add("fixture-main","/ok");root.add("fixture-wull","/ok")
    root.add("fixture-failure","/failure");root.add("fixture-slow","/slow")
    Ai.modelList=Object.keys(Ai.models)
    Ai.models["fixture-wull"].requires_key=true
    Ai.models["fixture-wull"].key_id="fixture";Ai.models["fixture-wull"].auth_scheme="bearer"
    Ai.currentModelId="fixture-main";Ai.addMessage("Ordinary AI history","user")
    root.mainIDs=Ai.messageIDs.slice()
    Config.setNestedValues({"abyss.companionMind.model":"fixture-wull",
     "abyss.companionMind.endpoint":"http://127.0.0.1:1",
     "abyss.companionMind.thinkingEffort":"high"})
    WullMind.historyLoaded=true;WullMind.openChat()
    if(!root.check(WullMind.selectableModels.some(entry=>entry.name==="fixture-wull"),"Wull exposes the AI catalog"))return
    if(!root.check(WullMind.sendMessage("Hello fixture"),"shared request accepted"))return
    root.step++
   }else if(root.step===1 && !WullMind.busy){
    if(!root.check(WullMind.history[WullMind.history.length-1]?.content==="Fixture hello"
        && WullMind.history[WullMind.history.length-1]?.persisted,"shared reply is rendered and persisted"))return
    if(!root.check(Ai.currentModelId==="fixture-main" && JSON.stringify(Ai.messageIDs)===JSON.stringify(root.mainIDs)
        && Ai.messageByID[root.mainIDs[0]].rawContent==="Ordinary AI history", "main AI conversation/model stay intact"))return
    Config.setNestedValue("abyss.companionMind.model","fixture-failure")
    if(!root.check(WullMind.sendMessage("Fail fixture"),"failure request accepted"))return
    root.step++
   }else if(root.step===2 && !WullMind.busy){
    if(!root.check(WullMind.connectionStatus==="error" && WullMind.errorMessage.includes("429"),"HTTP errors do not become successful replies"))return
    Config.setNestedValue("abyss.companionMind.model","fixture-slow")
    if(!root.check(WullMind.sendMessage("Cancel fixture"),"cancellable request accepted"))return
    root.step++
   }else if(root.step===3){WullMind.cancel();root.step++
   }else if(root.step===4 && !WullMind.aiSession.busy){
    if(!root.check(!WullMind.history.some(entry=>entry.content==="Cancel fixture"),"cancelled pending message is released"))return
    Config.setNestedValue("abyss.companionMind.model","")
    if(!root.check(WullMind.model===Ai.currentModelId,"empty override follows the AI tab model"))return
    if(!root.check(WullMind.sendMessage("Retry fixture"),"request works after cancellation"))return
    root.step++
   }else if(root.step===5 && !WullMind.busy){
    if(!root.check(WullMind.history[WullMind.history.length-1]?.content==="Fixture hello" && Ai.messageIDs.length===root.mainIDs.length,"retry preserves both conversations"))return
    console.info("WULL_SHARED_AI_PASS catalog request history-isolation persistence HTTP-error cancel retry model-follow");Qt.quit()
   }
  }
 }
}
''')
    with private_wayland(folder) as env:
        if env is None:
            print("SKIP: Wull shared AI runtime requires a private Niri session")
            raise SystemExit(0)
        env["AI_FIXTURE_URL"]=f"http://127.0.0.1:{server.server_port}"
        result=run_qs(folder,env)
    output=result.stdout+result.stderr
    errors=["WULL_SHARED_AI_FAIL","ReferenceError:","TypeError:","Binding loop","Unable to assign","is not a type"]
    if result.returncode or "WULL_SHARED_AI_PASS" not in output or any(word in output for word in errors):
        print(output);raise SystemExit(1)
    for line in output.splitlines():
        if "WULL_SHARED_AI_PASS" in line:print(line)
    ok=[row for path,row,headers in requests if path=="/ok"]
    assert len(ok)==2 and ok[0]["reasoning_effort"]=="high"
    assert all("Ordinary AI history" not in json.dumps(row) and "tools" not in row for row in ok)
    headers=[headers for path,row,headers in requests if path=="/ok"]
    assert headers[0].get("Authorization")=="Bearer fixture-credential"
    assert "Authorization" not in headers[1], "previous provider credential survived a keyless switch"
finally:
    server.shutdown();server.server_close()
