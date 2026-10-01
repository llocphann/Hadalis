import assert from "node:assert/strict";
import {nativePreflight, nativeSubmit, selectThinkingModel} from "../automation/chat_bridge/native_adapter.mjs";
import {operationErrorCode} from "../automation/chat_bridge/native_errors.mjs";

const makeModel = (slug, efforts, extra = {}) => ({slug, configurable_thinking_effort:true,
  thinking_efforts:efforts.map(thinking_effort => ({thinking_effort})), ...extra});
const metadata = {default_model_slug:"chat-auto", privateBody:"PRIVATE_CANARY",
  models:[makeModel("chat-auto", ["min","standard"]), makeModel("chat-thinking", ["standard","extended","xhigh","max"]),
    makeModel("work-only", ["max"], {is_work_mode_model:true})],
  categories:[{model_lane:"instant",default_model:"chat-auto",supported_models:["chat-auto"]},
    {model_lane:"thinking",default_model:"chat-thinking",supported_models:["chat-thinking"]}]};
assert.deepEqual(selectThinkingModel(metadata,"standard"),{model:"chat-auto",thinking_effort:"standard"});
assert.deepEqual(selectThinkingModel(metadata,"extended"),{model:"chat-thinking",thinking_effort:"extended"});
assert.deepEqual(selectThinkingModel(metadata,"standard","chat-thinking"),{model:"chat-thinking",thinking_effort:"standard"});
assert.throws(() => selectThinkingModel(metadata,"extended","chat-auto"),/THINKING_EFFORT_UNAVAILABLE/);
for (const m of [{is_work_mode_model:true},{tags:["hidden"]},{configurable_thinking_effort:false},{disabled_by_admin:true}])
  assert.throws(() => selectThinkingModel({models:[makeModel("only",["max"],m)]},"max"),/THINKING_EFFORT_UNAVAILABLE/);
assert.throws(() => selectThinkingModel({...metadata,categories:metadata.categories.map(c=>({...c,disabled_by_admin:true}))},"max"),/THINKING_EFFORT_UNAVAILABLE/);
assert.throws(() => selectThinkingModel({models:[makeModel("ambiguous-1",["max"]),makeModel("ambiguous-2",["max"])]},"max"),/THINKING_EFFORT_UNAVAILABLE/);
assert.throws(() => selectThinkingModel(metadata,"high"),/THINKING_EFFORT_UNAVAILABLE/);
assert.equal(operationErrorCode(new Error("THINKING_EFFORT_UNAVAILABLE")),"THINKING_EFFORT_UNAVAILABLE");

const previous = globalThis.window;
try {
  let reads=0, prepared=0, sent=0;
  const requests=[];
  globalThis.window={__hadalisReceipts:new Map(), __hadalisNative:{api:{safeGet:async(path)=>{
    ++reads; assert.equal(path,"/models");return structuredClone(metadata);
  }},transport:{prepareCompletionStream:async request=>{++prepared;requests.push(structuredClone(request));return {};},
    startCompletionStream:async options=>{
      ++sent;
      assert.deepEqual(options.request,requests.at(-1));
      options.onRequestStart();options.onResponse();
      options.onUpdate({conversation_id:"aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa"});options.onComplete();
    }}}};
  const page={evaluate:async(fn,arg)=>fn(arg)};
  assert.deepEqual(await nativePreflight(page,{}),{ready:true});assert.equal(reads,0);
  const selection=await nativePreflight(page,{thinking_effort:"extended"});
  assert.deepEqual(selection,{ready:true,model:"chat-thinking",thinking_effort:"extended"});
  assert.equal(JSON.stringify(selection).includes("PRIVATE_CANARY"),false);
  await assert.rejects(nativePreflight(page,{thinking_effort:"max",model:"chat-auto"}),/THINKING_EFFORT_UNAVAILABLE/);
  assert.equal(prepared,0);assert.equal(sent,0);
  let n=0;
  for (const effort of [undefined,"auto","min","standard","extended","xhigh","max"]) {
    const input={user_message_id:`bbbbbbbb-bbbb-4bbb-bbbb-${String(++n).padStart(12,"0")}`,
      parent_message_id:"cccccccc-cccc-4ccc-cccc-cccccccccccc",prompt:"Keep this exact objective.  \n"};
    if (effort !== undefined) input.thinking_effort=effort;
    if (effort && effort !== "auto") input.model="chat-thinking";
    const receipt=await nativeSubmit(page,input);
    assert.equal(receipt.dispatched,true);assert.equal(receipt.streamComplete,true);
    const request=requests.at(-1);
    assert.equal(request.messages[0].content.parts[0],input.prompt);
    assert.equal(request.model,input.model??"auto");
    if (effort === undefined || effort === "auto") assert.equal("thinking_effort" in request,false);
    else assert.equal(request.thinking_effort,effort);
    // The same user identity cannot be sent again with a changed setting.
    const count=sent;
    assert.deepEqual(await nativeSubmit(page,{...input,thinking_effort:"standard"}),receipt);
    assert.equal(sent,count);
  }
  const count=sent;
  await assert.rejects(nativeSubmit(page,{user_message_id:"dddddddd-dddd-4ddd-dddd-dddddddddddd",
    parent_message_id:"cccccccc-cccc-4ccc-cccc-cccccccccccc",thinking_effort:"PRIVATE_CANARY"}),/THINKING_EFFORT_UNAVAILABLE/);
  assert.equal(sent,count);
} finally {
  if (previous === undefined) delete globalThis.window;
  else globalThis.window=previous;
}
console.log("PASS: Chat-only supported model selection, preflight without dispatch, Auto omission, exact effort wire values and identity deduplication");
