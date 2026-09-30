import assert from "node:assert/strict";
import {projectTurn, installedContract, nativeStreamStatus} from "../automation/chat_bridge/native_adapter.mjs";
const message = (id, role, status, end, text, recipient = "all", channel = null) =>
  ({id, author:{role}, status, end_turn:end, recipient, channel, content:{parts:[text]}});
const c = {conversation_id:"chat-A",current_node:"a",mapping:{
  u:{id:"u",parent:null,message:message("u","user","finished_successfully",true,"HADALIS_LOOP:DONE")},
  a:{id:"a",parent:"u",message:message("a","assistant","in_progress",false,"HADALIS_LOOP:DONE")}}};
const p = {conversation_id:"chat-A",user_message_id:"u"};
assert.equal(projectTurn(c,p).completed,false); // A marker while streaming is not completion.
c.mapping.a.message.status="finished_successfully";
assert.equal(projectTurn(c,p).completed,false); // Tool/computation partial is not final.
c.mapping.a.message.end_turn=true;
assert.equal(projectTurn(c,p).response.message_id,"a");
assert.equal(projectTurn(c,{...p,user_message_id:"other"}).submitted,false);
assert.throws(()=>projectTurn(c,{...p,conversation_id:"chat-B"}),/identity/);
c.mapping.a.message.recipient="functions.exec";
assert.equal(projectTurn(c,p).completed,false);
c.mapping.a.message.recipient="all";
c.mapping.a.message.status="error";
assert.equal(projectTurn(c,p).streamError,true);
assert.equal(projectTurn(c,p).terminal_failed,true);
c.mapping.a.message.end_turn=false;
assert.equal(projectTurn(c,p).terminal_failed,false);
c.mapping.b={id:"b",parent:"a",message:message("b","user","finished_successfully",true,"next")};
c.mapping.z={id:"z",parent:"b",message:message("z","assistant","finished_successfully",true,"HADALIS_LOOP:DONE")};c.current_node="z";
assert.equal(projectTurn(c,p).completed,false); // Never consume the next user's reply.
assert.equal(projectTurn(c,p).superseded,true);
assert.equal(projectTurn(c,p).successor_user_message_id,"b");
assert.equal(projectTurn(c,{...p,user_message_id:"b"}).response.message_id,"z");
const pending={conversation_id:"aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa",user_message_id:"bbbbbbbb-bbbb-4bbb-bbbb-bbbbbbbbbbbb"};
const previousWindow=globalThis.window;
try {
  globalThis.window={__hadalisReceipts:new Map()};
  const page={evaluate:async(fn,arg)=>fn(arg)};
  assert.deepEqual(await nativeStreamStatus(page,pending),{found:false});
  window.__hadalisReceipts.set(pending.user_message_id,{conversation_id:pending.conversation_id,
    dispatched:true,accepted:true,streamError:true,streamComplete:false,dispatched_at_ms:1000,
    completed_at_ms:"private-canary",localError:"private-canary",prompt:"private-canary"});
  const status=await nativeStreamStatus(page,pending);
  assert.equal(status.streamError,true);
  assert.equal(status.streamComplete,false);
  assert.equal(status.dispatched_at_ms,1000);
  assert.equal(JSON.stringify(status).includes("private-canary"),false);
  assert.equal("completed_at_ms" in status,false);
  window.__hadalisReceipts.get(pending.user_message_id).conversation_id="cccccccc-cccc-4ccc-cccc-cccccccccccc";
  await assert.rejects(nativeStreamStatus(page,pending),/identity mismatch/);
  await assert.rejects(nativeStreamStatus(page,{...pending,user_message_id:"invalid"}),/identity/);
} finally {
  if (previousWindow===undefined) delete globalThis.window;
  else globalThis.window=previousWindow;
}
if (process.env.HADALIS_TEST_INSTALLED_DESKTOP === "1") assert.ok(installedContract().api);
console.log("PASS: conversation identity, final message receipt, no cross-turn completion and bounded private stream status");
