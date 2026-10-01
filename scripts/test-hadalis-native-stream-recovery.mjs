import assert from "node:assert/strict";
import {pollNativeTurn, nativeServerStreamStatus, nativeRead, nativeModelCatalog} from "../automation/chat_bridge/native_adapter.mjs";
import {operationErrorCode, operationErrorObservation} from "../automation/chat_bridge/native_errors.mjs";

const chat="aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa";
const user="bbbbbbbb-bbbb-4bbb-bbbb-bbbbbbbbbbbb";
const pending={conversation_id:chat,user_message_id:user,project_id:"g-p-"+"d".repeat(32),prepared_at_unix:Date.now()/1000};
const message=(id,role,status="finished_successfully",end_turn=true)=>({id,author:{role},status,end_turn,
  recipient:"all",channel:role==="assistant"?"final":null,content:{parts:["HADALIS_LOOP:CONTINUE"]}});
const history={conversation_id:chat,current_node:user,mapping:{
  [user]:{id:user,parent:null,message:message(user,"user")}}};
const next={conversation_id:chat,current_node:"next",mapping:{...history.mapping,
  next:{id:"next",parent:user,message:message("next","user")}}};
const finished={conversation_id:chat,current_node:"final",mapping:{...history.mapping,
  final:{id:"final",parent:user,message:message("final","assistant")}}};
const previousWindow=globalThis.window;

async function observe({status="FAILURE",latest=history,receipt=true,receiptState={streamError:true},aged=false,serverError=null,capability=true}={}) {
  const calls=[];let reads=0;
  globalThis.window={__hadalisReceipts:new Map(receipt?[[user,{conversation_id:chat,...receiptState}]]:[]),
    __hadalisNative:{serverStreamStatus:capability,api:{safeGet:async(path,options)=>{
      calls.push(path);
      if (path===`/conversation/${chat}`) {
        assert.equal(options.additionalHeaders["chatgpt-project-id"],pending.project_id);
        return structuredClone(reads++ ? latest : history);
      }
      assert.equal(path,"/conversation/{conversation_id}/stream_status");
      assert.equal(options.parameters.path.conversation_id,chat);
      if (serverError) throw serverError;
      return {status,privateBody:"PRIVATE_CANARY"};
    }}}};
  const result=await pollNativeTurn({evaluate:async(fn,arg)=>fn(arg)},
    {...pending,prepared_at_unix:pending.prepared_at_unix-(aged?600:0)});
  assert.equal(JSON.stringify(result).includes("PRIVATE_CANARY"),false);
  return {result,calls};
}

try {
  const failed=await observe();
  assert.equal(failed.result.terminal_failed,true);
  assert.equal(failed.result.terminal_failure_source,"conversation_stream_status");
  assert.equal(failed.result.server_stream_status,"FAILURE");
  assert.equal(failed.calls.length,3); // Two exact-turn histories bracket server status.
  for (const status of ["IS_STREAMING","COMPLETE","UNAVAILABLE","new-unknown-value"]) {
    const {result}=await observe({status});
    assert.equal(result.completed,false);
    assert.equal(result.terminal_failed,false);
    assert.equal(result.client_stream_error,true);
    assert.equal(result.client_stream_complete,false);
    assert.equal(result.streamError,false); // Client error cannot become server failure evidence.
  }
  const closedAfterRestart=await observe({status:"COMPLETE",receipt:false,aged:true});
  assert.equal(closedAfterRestart.result.server_stream_status,"COMPLETE");
  assert.equal(closedAfterRestart.result.client_stream_error,false);
  assert.equal(closedAfterRestart.result.terminal_failed,false);
  const clientClosed=await observe({status:"UNAVAILABLE",receiptState:{streamComplete:true}});
  assert.equal(clientClosed.result.client_stream_complete,true);
  assert.equal(clientClosed.result.client_stream_error,false);
  assert.equal(clientClosed.result.terminal_failed,false);
  const superseded=await observe({latest:next});
  assert.equal(superseded.result.superseded,true);
  assert.equal(superseded.result.terminal_failed,false);
  const persisted=await observe({latest:finished});
  assert.equal(persisted.result.completed,true);
  assert.equal(persisted.result.response.message_id,"final");
  const changed=structuredClone(history);
  changed.current_node="reasoning";
  changed.mapping.reasoning={id:"reasoning",parent:user,message:{...message("reasoning","assistant","in_progress",false),channel:"analysis"}};
  assert.equal((await observe({latest:changed})).result.terminal_failed,false);
  const restarted=await observe({receipt:false,aged:true});
  assert.equal(restarted.result.terminal_failed,true); // Desktop receipt loss cannot disable recovery.
  assert.equal((await observe({receipt:false})).calls.length,1);
  assert.equal((await observe({capability:false})).result.terminal_failed,false);
  assert.equal((await observe({serverError:{responseStatus:404}})).result.terminal_failed,false);
  await assert.rejects(observe({serverError:{responseStatus:429,message:"PRIVATE_CANARY"}}),
    error=>{
      assert.deepEqual(operationErrorObservation(error),{code:"DESKTOP_RATE_LIMITED",http_status:429,resource:"stream_status"});
      return !JSON.stringify(error).includes("PRIVATE_CANARY");
    });
  // Simulate the IPC boundary that strips custom fields from thrown errors.
  // The adapter must project HTTP metadata inside Desktop before crossing it.
  const ipcPage={evaluate:async(fn,arg)=>{
    try{return JSON.parse(JSON.stringify(await fn(arg)));}
    catch(error){throw new Error(error.message);}
  }};
  window.__hadalisNative.api.safeGet=async()=>{throw {responseStatus:429,message:"PRIVATE_CANARY",headers:{authorization:"PRIVATE_CANARY"}};};
  await assert.rejects(nativeRead(ipcPage,`/conversation/${chat}`),error=>{
    assert.deepEqual(operationErrorObservation(error),{code:"DESKTOP_RATE_LIMITED",http_status:429,resource:"conversation"});
    return !JSON.stringify(error).includes("PRIVATE_CANARY");
  });
  window.__hadalisNative.api.safeGet=async()=>{throw {name:"AbortError",message:"PRIVATE_CANARY"};};
  await assert.rejects(nativeRead(ipcPage,"/models"),error=>{
    assert.deepEqual(operationErrorObservation(error),{code:"DESKTOP_OPERATION_TIMEOUT",resource:"models"});return true;
  });
  window.__hadalisNative.api.safeGet=async()=>({default_model_slug:"chat",account:"PRIVATE_CANARY",
    models:[{slug:"chat",description:"PRIVATE_CANARY",thinking_efforts:[{thinking_effort:"extended"}]}],
    categories:[{default_model:"chat",supported_models:["chat"],model_lane:"thinking",short_explainer:"PRIVATE_CANARY"}]});
  const catalog=await nativeModelCatalog(ipcPage);
  assert.equal(catalog.models[0].slug,"chat");assert.deepEqual(catalog.models[0].thinking_efforts,["extended"]);
  assert.equal(catalog.categories[0].model_lane,"thinking");
  assert.equal(JSON.stringify(catalog).includes("PRIVATE_CANARY"),false);
  await assert.rejects(nativeServerStreamStatus({evaluate:()=>assert.fail("invalid identity reached API")},"bad"),/identity/);
  window.__hadalisNative.api.safeGet=async(_path,options)=>{
    assert.equal("additionalHeaders" in options,false);
    return {};
  };
  await nativeRead({evaluate:async(fn,arg)=>fn(arg)},`/conversation/${chat}`,{},"g-custom-legacy");
  await nativeRead({evaluate:async(fn,arg)=>fn(arg)},`/conversation/${chat}`,{},"PRIVATE_CANARY\r\nheader: injected");
} finally {
  if (previousWindow===undefined) delete globalThis.window;
  else globalThis.window=previousWindow;
}
console.log("PASS: missing-assistant stream failure, exact-turn bracket, restart recovery, later-user/final-response protection, unavailable status and private rate-limit handling");
