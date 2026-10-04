import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import {spawnSync} from "node:child_process";
import {fileURLToPath} from "node:url";
import {inspectContractAssets, installedContract, exactSharedImport, publicExportExists} from "../automation/chat_bridge/native_adapter.mjs";
import {operationErrorCode} from "../automation/chat_bridge/native_errors.mjs";

const quote = String.fromCharCode(96);
const initial = [
  "import{apiClient as client}from './app-shared-def.js';",
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
assert.equal(result.checks.api_exact_binding,true);
assert.equal(result.checks.api_exact_export,true);
assert.equal(result.checks.api_runtime_link,true);
assert.equal(result.checks.api_import,true);
// The shared module exports "apiClient", not its internal local "Client".
assert.equal(result.checks.api_export,false);
assert.equal(result.contract.api,"apiClient");
assert.equal(result.contract.stream,"exportedScope");
const direct = initial.replace("import{apiClient as client}", "import{apiClient}")
  .replace("client.streamPost", "apiClient.streamPost");
assert.equal(inspectContractAssets(fake(direct)).contract.api,"apiClient");
assert.equal(exactSharedImport(initial,"app-shared-def.js","client"),"apiClient");
assert.equal(exactSharedImport(initial,"app-shared-def.js","unused"),null);
assert.equal(publicExportExists(shared,"apiClient"),true);
assert.equal(publicExportExists(shared,"Client"),false);
// A symbol imported from the right module but not exported by it is NOT
// treated as a verified native client.
const missingExport = initial.replace("apiClient as client","missingApi as client");
const missing = inspectContractAssets(fake(missingExport));
assert.equal(missing.checks.api_exact_binding,true);
assert.equal(missing.checks.api_exact_export,false);
assert.equal(missing.contract.api_resolution,"unique_runtime_export");


// A changed upstream import alias may prevent a static export lookup.
// The fallback is allowed only when the exact shared asset is referenced;
// runtime must still find exactly one API object with both capabilities.
const alteredImport = initial.replace(
  "import{apiClient as client}from './app-shared-def.js';",
  "import{Unknown as unused}from './app-shared-def.js';"
);
const fallback = inspectContractAssets(fake(alteredImport));
assert.ok(fallback.contract);
assert.equal(fallback.checks.api_import, false);
assert.equal(fallback.checks.api_export, false);
assert.equal(fallback.checks.api_runtime_link, true);
assert.equal(fallback.contract.api, null);
assert.equal(fallback.contract.api_resolution, "unique_runtime_export");
const unlinked = inspectContractAssets(fake(
  alteredImport.replace("app-shared-def.js", "unrelated.js")
));
assert.equal(unlinked.contract, null);
assert.equal(unlinked.checks.api_runtime_link, false);
assert.equal(result.contract.api_resolution, "static_export");


// Neighboring minifier symbols must not determine compatibility.
const renamed = inspectContractAssets(fake(initial.replace("other=1","other=1,unrelated=3")));
assert.ok(renamed.contract);
const noMethod = inspectContractAssets(fake(initial.replace("startCompletionStream","unrelatedMethod")));
assert.equal(noMethod.contract,null);
assert.equal(noMethod.checks.stream_method,false);
const noHook = inspectContractAssets(fake(initial.replace("streamPost","someOtherCall")));
assert.equal(noHook.contract,null);
assert.equal(noHook.checks.conversation_stream_hook,false);
const ambiguous=inspectContractAssets(fake(initial
  .replace("other=1,scoped=", "other=1,extra=wrap($,({scope:e})=>new Else(e)),scoped=")
  .replace("export{scoped as exportedScope}",
    "export{scoped as exportedScope,extra as exportedOther}")
));
assert.equal(ambiguous.contract,null);
assert.equal(ambiguous.checks.stream_scope,false);
assert.equal(inspectContractAssets({files:[],read(){throw Error("unexpected read")}}).checks.initial_asset,false);
assert.equal(operationErrorCode(new Error("unsupported Desktop stream contract [stream_scope]")),"DESKTOP_CAPABILITY_UNAVAILABLE");
assert.equal(typeof installedContract,"function");

// The CLI must classify an incompatible installed bundle before CDP import,
// without connecting to a real Desktop, hanging, or leaking archive source.
const temp = fs.mkdtempSync(path.join(os.tmpdir(), "hadalis-contract-test-"));
try {
  const badInitial = Buffer.from(initial.replace("startCompletionStream", "missingMethod"));
  const sharedBytes = Buffer.from(shared);
  const entries = {
    "app-initial-test.js":{size:badInitial.length,offset:"0"},
    "app-shared-test.js":{size:sharedBytes.length,offset:String(badInitial.length)}
  };
  const manifest = Buffer.from(JSON.stringify({
    files:{webview:{files:{assets:{files:entries}}}}
  }));
  const header = Buffer.alloc(16);
  header.writeUInt32LE(manifest.length + 8, 4);
  header.writeUInt32LE(manifest.length, 12);
  const archive = path.join(temp, "fake.asar");
  fs.writeFileSync(archive, Buffer.concat([header,manifest,badInitial,sharedBytes]), {mode:0o600});
  const start = Date.now();
  const cli = spawnSync(process.execPath, [
    fileURLToPath(new URL("../automation/chat_bridge/native_cli.mjs", import.meta.url))
  ], {
    input:JSON.stringify({op:"probe",error_observation:true}),
    encoding:"utf8", timeout:6000,
    env:{...process.env,HADALIS_DESKTOP_ASAR:archive,
      HADALIS_CHATGPT_CDP_URL:"http://127.0.0.1:1",
      HADALIS_PLAYWRIGHT_MODULE:"file:///nonexistent/playwright.mjs"}
  });
  assert.equal(cli.error,undefined);
  assert.equal(cli.status,1);
  assert.equal(JSON.parse(cli.stderr.trim()).code,"DESKTOP_CAPABILITY_UNAVAILABLE");
  assert.ok(Date.now()-start < 6000);
  const diagnostic = spawnSync(process.execPath, [
    fileURLToPath(new URL("../automation/chat_bridge/native_cli.mjs", import.meta.url))
  ], {
    input:JSON.stringify({op:"diagnose",error_observation:true}),
    encoding:"utf8", timeout:6000,
    env:{...process.env,HADALIS_DESKTOP_ASAR:archive,
      HADALIS_CHATGPT_CDP_URL:"http://127.0.0.1:1",
      HADALIS_PLAYWRIGHT_MODULE:"file:///nonexistent/playwright.mjs"}
  });
  assert.equal(diagnostic.error,undefined);
  assert.equal(diagnostic.status,0);
  const diagnosed = JSON.parse(diagnostic.stdout.trim());
  assert.equal(diagnosed.contract_inspected,true);
  assert.equal(diagnosed.contract_supported,false);
  assert.equal(diagnosed.contract_stream_method,false);
  assert.equal(diagnosed.contract_initial_asset,true);
  assert.equal(diagnosed.contract_shared_asset,true);
  assert.equal("renderer_found" in diagnosed,false);
  assert.equal(JSON.stringify(diagnosed).includes(temp),false);
  assert.equal(JSON.stringify(diagnosed).includes("missingMethod"),false);
} finally {
  fs.rmSync(temp,{recursive:true,force:true});
}

console.log("PASS: native contract structural/ambiguity/fail-closed diagnostics and early CLI rejection");
