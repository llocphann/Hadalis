import assert from "node:assert/strict";
import {classifyManagedBranch, nativeManagedBranch} from "../automation/chat_bridge/native_adapter.mjs";

const node=(parent,role,id)=>({parent,message:{id,author:{role}}});
const base={current_node:"response",mapping:{
  user:node(null,"user","u"), response:node("user","assistant","expected")
}};
assert.equal(classifyManagedBranch(base,"expected"),"EXACT_CURRENT_NODE");
assert.equal(classifyManagedBranch(base,"response"),"EXACT_CURRENT_NODE");
const descendant={current_node:"internal",mapping:{...base.mapping,
  internal:node("response","tool","internal")}};
assert.equal(classifyManagedBranch(descendant,"expected"),"NON_USER_DESCENDANT");
const later={current_node:"new_answer",mapping:{...descendant.mapping,
  later_user:node("internal","user","u2"),
  new_answer:node("later_user","assistant","a2")}};
assert.equal(classifyManagedBranch(later,"expected"),"LATER_USER_TURN");
const sibling={current_node:"sibling",mapping:{...later.mapping,
  sibling:node("user","assistant","alternate")}};
assert.equal(classifyManagedBranch(sibling,"expected"),"DIFFERENT_BRANCH");
assert.equal(classifyManagedBranch(sibling,"unknown"),"EXPECTED_RESPONSE_NOT_IN_HISTORY");
assert.equal(classifyManagedBranch({current_node:"a",mapping:{a:node("a","tool","a")}},"other"),
  "HISTORY_UNAVAILABLE");
assert.equal(classifyManagedBranch({current_node:"a",mapping:{}},"expected"),
  "EXPECTED_RESPONSE_NOT_IN_HISTORY");
assert.equal(classifyManagedBranch({mapping:{}},"expected"),"HISTORY_UNAVAILABLE");

// A verified parent is returned ONLY if its exact branch and UUID are sound.
const id="aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";
const descendantId="bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb";
const conversationId="cccccccc-cccc-4ccc-8ccc-cccccccccccc";
const verified={conversation_id:conversationId,current_node:descendantId,
  mapping:{
    [id]:node(null,"assistant",id),
    [descendantId]:node(id,"tool",descendantId)
  }};
const fakePage=history=>({
  evaluate:async (_fn,args)=>{
    assert.equal(args.path,"/conversation/"+conversationId);
    return {ok:true,value:history};
  }
});
assert.deepEqual(await nativeManagedBranch(fakePage(verified),
  conversationId,null,id),{relation:"NON_USER_DESCENDANT",current_node:descendantId});
const human={...verified,current_node:"dddddddd-dddd-4ddd-8ddd-dddddddddddd",
  mapping:{...verified.mapping,
    "dddddddd-dddd-4ddd-8ddd-dddddddddddd":node(descendantId,"user","other")}
};
assert.deepEqual(await nativeManagedBranch(fakePage(human),
  conversationId,null,id),{relation:"LATER_USER_TURN"});
const invalidCursor={...verified,current_node:"not-a-uuid",
  mapping:{...verified.mapping,"not-a-uuid":node(descendantId,"tool","not-a-uuid")}};
assert.deepEqual(await nativeManagedBranch(fakePage(invalidCursor),
  conversationId,null,id),{relation:"NON_USER_DESCENDANT"});

console.log("PASS: compact managed-chat branch classification and identity isolation");
