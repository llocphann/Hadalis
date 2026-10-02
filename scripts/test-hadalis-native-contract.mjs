import assert from "node:assert/strict";
import {inspectContractAssets, installedContract} from "../automation/chat_bridge/native_adapter.mjs";
import {operationErrorCode} from "../automation/chat_bridge/native_errors.mjs";

const quote = String.fromCharCode(96);
const initial = [
  "import{Client as client}from './shared.js';",
  "var other=1,scoped=wrap($,({scope:e})=>new Carrier(e));",
  "client.streamPost(" + quote + "/f/conversation" + quote + ");",
  "class Carrier {async startCompletionStream() {}}",
  "export{scoped as exportedScope}"
].join("");
const shared = "export{Client as apiClient}";
const fake = (initialText=initial, sharedText=shared) => ({
  files:["app-initial-abc.js","app-shared-def.js"],
  read(name) { return name.startsWith("app-initial") ? initialText : sharedText; }
});

const result=inspectContractAssets(fake());
assert.ok(result.contract);
assert.deepEqual(Object.values(result.checks), Array(8).fill(true));
assert.equal(result.contract.api,"apiClient");
assert.equal(result.contract.stream,"exportedScope");

// Neighboring minifier symbols must not determine compatibility.
const renamed = inspectContractAssets(fake(initial.replace("other=1","other=1,unrelated=3")));
assert.ok(renamed.contract);
const noMethod = inspectContractAssets(fake(initial.replace("startCompletionStream","unrelatedMethod")));
assert.equal(noMethod.contract,null);
assert.equal(noMethod.checks.stream_method,false);
const noHook = inspectContractAssets(fake(initial.replace("streamPost","someOtherCall")));
assert.equal(noHook.contract,null);
assert.equal(noHook.checks.conversation_stream_hook,false);
const ambiguous=inspectContractAssets(fake(initial.replace(
  "export{scoped as exportedScope}",
  "var extra=wrap($,({scope:e})=>new Else(e));export{scoped as exportedScope,extra as exportedOther}"
)));
assert.equal(ambiguous.contract,null);
assert.equal(ambiguous.checks.stream_scope,false);
assert.equal(inspectContractAssets({files:[],read(){throw Error("unexpected read")}}).checks.initial_asset,false);
assert.equal(operationErrorCode(new Error("unsupported Desktop stream contract [stream_scope]")),"DESKTOP_CAPABILITY_UNAVAILABLE");
assert.equal(typeof installedContract,"function");
console.log("PASS: native contract structural/ambiguity/fail-closed diagnostics");
