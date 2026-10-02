import assert from "node:assert/strict";
import {classifyManagedBranch} from "../automation/chat_bridge/native_adapter.mjs";

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
console.log("PASS: compact managed-chat branch classification and identity isolation");
