import assert from "node:assert/strict";
import {nativePreflight, nativeSubmit, selectThinkingModel} from "../automation/chat_bridge/native_adapter.mjs";
import {operationErrorCode} from "../automation/chat_bridge/native_errors.mjs";

const makeModel = (slug, efforts, extra = {}) => ({slug, configurable_thinking_effort:true,
  thinking_efforts:efforts.map(thinking_effort => ({thinking_effort})), ...extra});
const metadata = {default_model_slug:"chat-auto", privateBody:"PRIVATE_CANARY",
  models:[makeModel("chat-auto", [], {configurable_thinking_effort:false}), makeModel("chat-thinking", ["min","standard","extended","xhigh","max"]),
    makeModel("work-only", ["max"], {is_work_mode_model:true})],
  categories:[{model_lane:"instant",default_model:"chat-auto",supported_models:["chat-auto"]},
    {model_lane:"thinking",default_model:"chat-thinking",supported_models:["chat-thinking"]}]};
assert.deepEqual(selectThinkingModel(metadata,"instant"),{model:"chat-auto",thinking_effort:"instant"});
assert.deepEqual(selectThinkingModel(metadata,"instant","chat-thinking"),{model:"chat-auto",thinking_effort:"instant"});
assert.deepEqual(selectThinkingModel(metadata,"standard"),{model:"chat-thinking",thinking_effort:"standard"});
assert.deepEqual(selectThinkingModel(metadata,"extended"),{model:"chat-thinking",thinking_effort:"extended"});
assert.deepEqual(selectThinkingModel(metadata,"standard","chat-thinking"),{model:"chat-thinking",thinking_effort:"standard"});
assert.deepEqual(selectThinkingModel(metadata,"extended","chat-auto"),{model:"chat-thinking",thinking_effort:"extended"});
assert.throws(() => selectThinkingModel({...metadata,categories:metadata.categories.slice(1)},"instant"),/THINKING_EFFORT_UNAVAILABLE/);
assert.throws(() => selectThinkingModel({...metadata,categories:metadata.categories.map(c=>({...c,disabled_by_admin:true}))},"instant"),/THINKING_EFFORT_UNAVAILABLE/);
assert.throws(() => selectThinkingModel({...metadata,models:metadata.models.map(m=>({...m,is_work_mode_model:true}))},"instant"),/THINKING_EFFORT_UNAVAILABLE/);
for (const m of [{is_work_mode_model:true},{tags:["hidden"]},{configurable_thinking_effort:false},{disabled_by_admin:true}])
  assert.throws(() => selectThinkingModel({models:[makeModel("only",["max"],m)]},"max"),/THINKING_EFFORT_UNAVAILABLE/);
assert.throws(() => selectThinkingModel({...metadata,categories:metadata.categories.map(c=>({...c,disabled_by_admin:true}))},"max"),/THINKING_EFFORT_UNAVAILABLE/);
assert.throws(() => selectThinkingModel({models:[makeModel("ambiguous-1",["max"]),makeModel("ambiguous-2",["max"])]},"max"),/THINKING_EFFORT_UNAVAILABLE/);
assert.throws(() => selectThinkingModel(metadata,"high"),/THINKING_EFFORT_UNAVAILABLE/);
assert.equal(operationErrorCode(new Error("THINKING_EFFORT_UNAVAILABLE")),"THINKING_EFFORT_UNAVAILABLE");

// Real account catalogs can list legacy categories before the current models.
// A continuation with an old default must still choose the highest enabled
// Chat model, independently of category/model ordering and Work availability.
const available={models:[makeModel("gpt-5-5-thinking",["standard","extended"]),
  makeModel("gpt-5-6-thinking",["standard","extended"]),
  makeModel("gpt-5-5-instant",[],{configurable_thinking_effort:false}),
  makeModel("gpt-5-6-instant",[],{configurable_thinking_effort:false}),
  makeModel("gpt-6-astra-wm",["standard","extended"],{is_work_mode_model:true})],
  categories:[
    {model_lane:"thinking",model_version:"5.5",default_model:"gpt-5-5-thinking"},
    {model_lane:"thinking",model_version:"5.6",default_model:"gpt-5-6-thinking"},
    {model_lane:"instant",model_version:"5.5",default_model:"gpt-5-5-instant"},
    {model_lane:"instant",model_version:"5.6",default_model:"gpt-5-6-instant"},
    {model_lane:"thinking",model_version:"6",default_model:"gpt-6-astra-wm"}]};
for (const effort of ["standard","extended","instant"])
  for (const reversed of [false,true]) {
    const data=structuredClone(available);
    if (reversed) {data.models.reverse();data.categories.reverse();}
    const lane=effort === "instant" ? "instant" : "thinking";
    assert.equal(selectThinkingModel(data,effort,`gpt-5-5-${lane}`).model,`gpt-5-6-${lane}`);
  }
const future=structuredClone(available);
future.models.push(makeModel("gpt-5-10-thinking",["standard","extended"]));
future.categories.push({model_lane:"thinking",model_version:"5.10",default_model:"gpt-5-10-thinking"});
assert.equal(selectThinkingModel(future,"extended").model,"gpt-5-10-thinking");
for (const flag of ["disabled_by_admin","is_work_mode_model"]) {
  const data=structuredClone(future);data.models.at(-1)[flag]=true;
  assert.equal(selectThinkingModel(data,"extended").model,"gpt-5-6-thinking");
}
const noVersion=structuredClone(available);
for (const c of noVersion.categories) delete c.model_version;
assert.equal(selectThinkingModel(noVersion,"extended").model,"gpt-5-6-thinking");
const unsupported=structuredClone(available);
unsupported.models[1].thinking_efforts=[{thinking_effort:"standard"}];
assert.throws(()=>selectThinkingModel(unsupported,"extended","gpt-5-5-thinking"),/THINKING_EFFORT_UNAVAILABLE/);
const unknown=structuredClone(available);
unknown.models.push(makeModel("unranked-chat",["extended"]));
unknown.categories.push({model_lane:"thinking",default_model:"unranked-chat"});
assert.throws(()=>selectThinkingModel(unknown,"extended"),/THINKING_EFFORT_UNAVAILABLE/);
const pro=structuredClone(available);
pro.models.push(makeModel("gpt-5-6-pro",["extended"]));
pro.categories.push({model_lane:"pro",model_version:"5.6",default_model:"gpt-5-6-pro"});
assert.equal(selectThinkingModel(pro,"extended").model,"gpt-5-6-pro");

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
  assert.deepEqual(await nativePreflight(page,{thinking_effort:"instant",model:"chat-thinking"}),
    {ready:true,model:"chat-auto",thinking_effort:"instant"});
  const originalRead=window.__hadalisNative.api.safeGet;
  window.__hadalisNative.api.safeGet=async()=>structuredClone(available);
  assert.deepEqual(await nativePreflight(page,{thinking_effort:"extended",model:"gpt-5-5-thinking"}),
    {ready:true,model:"gpt-5-6-thinking",thinking_effort:"extended"});
  window.__hadalisNative.api.safeGet=originalRead;
  await assert.rejects(nativePreflight(page,{thinking_effort:"ultra"}),/THINKING_EFFORT_UNAVAILABLE/);
  assert.equal(prepared,0);assert.equal(sent,0);
  let n=0;
  for (const effort of [undefined,"auto","instant","min","standard","extended","xhigh","max"]) {
    const input={user_message_id:`bbbbbbbb-bbbb-4bbb-bbbb-${String(++n).padStart(12,"0")}`,
      parent_message_id:"cccccccc-cccc-4ccc-cccc-cccccccccccc",prompt:"Keep this exact objective.  \n"};
    if (effort !== undefined) input.thinking_effort=effort;
    if (effort && effort !== "auto") input.model=effort === "instant" ? "chat-auto" : "chat-thinking";
    const receipt=await nativeSubmit(page,input);
    assert.equal(receipt.dispatched,true);assert.equal(receipt.streamComplete,true);
    const request=requests.at(-1);
    assert.equal(request.messages[0].content.parts[0],input.prompt);
    assert.equal(request.model,input.model??"auto");
    if (effort === undefined || effort === "auto" || effort === "instant") assert.equal("thinking_effort" in request,false);
    else assert.equal(request.thinking_effort,effort);
    // The same user identity cannot be sent again with a changed setting.
    const count=sent;
    assert.deepEqual(await nativeSubmit(page,{...input,thinking_effort:"standard"}),receipt);
    assert.equal(sent,count);
  }
  const count=sent;
  await assert.rejects(nativeSubmit(page,{user_message_id:"eeeeeeee-eeee-4eee-eeee-eeeeeeeeeeee",
    parent_message_id:"cccccccc-cccc-4ccc-cccc-cccccccccccc",thinking_effort:"instant"}),/THINKING_EFFORT_UNAVAILABLE/);
  await assert.rejects(nativeSubmit(page,{user_message_id:"dddddddd-dddd-4ddd-dddd-dddddddddddd",
    parent_message_id:"cccccccc-cccc-4ccc-cccc-cccccccccccc",thinking_effort:"PRIVATE_CANARY"}),/THINKING_EFFORT_UNAVAILABLE/);
  assert.equal(sent,count);
} finally {
  if (previous === undefined) delete globalThis.window;
  else globalThis.window=previous;
}
console.log("PASS: highest available Chat versions, ordering/continuation upgrades, no model downgrade, Instant/Thinking lanes, exact wire values and identity deduplication");
