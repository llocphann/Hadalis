#!/usr/bin/env node
"use strict";
// Pure synthetic cases; never invoke MEGAcmd or access user information.
import assert from "node:assert/strict";
import fs from "node:fs";
import vm from "node:vm";
import path from "node:path";
import {fileURLToPath} from "node:url";
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const parse = vm.runInNewContext(
    fs.readFileSync(path.join(__dirname, "../services/deferred/CloudStorageStaticProtocol.js"), "utf8")
    + "\nparseDetectResponse", Object.create(null), {timeout: 2000});
const names = ["mega-cmd","mega-login","mega-cmd-server","mega-whoami","mega-version"];
const good = () => ({
    protocol: 1, request_id: "test-id", ok: true, error: null,
    result: {
        adapter: "inir-mega", probe_kind: "static_no_vendor_execution",
        vendor_execution: "auth_blocked_pending_disposable_qualification",
        auth_transport: "private_pty_fake_qualified",
        secret_argv: false, python_mutation_fallback: false,
        interactive_shell_available: true, server_available: true,
        binaries: names.map(name=>({name, executable:true, path:"/sensitive/fixture/" + name}))
    }
});
let count = 0;
let result = parse(JSON.stringify(good()), "test-id");
assert.equal(result.installed, true);
for (const key of ["shell", "login", "server", "whoami", "version"])
    assert.equal(result[key], true, "fixture exposes static " + key);
assert.equal(JSON.stringify(result).includes("/sensitive/"), false); count++;
const partial = good();
partial.result.server_available = false;
partial.result.binaries[2].executable = false;
const parsedPartial = parse(JSON.stringify(partial), "test-id");
assert.equal(parsedPartial.installed, false);
assert.equal(parsedPartial.login, true);
assert.equal(parsedPartial.server, false); count++;
const noCanonicalPath = good();
noCanonicalPath.result.binaries[0].path = null;
assert.equal(parse(JSON.stringify(noCanonicalPath), "test-id").installed, true); count++;
const secondary = good();
secondary.result.binaries[1].executable = false;
secondary.result.binaries[3].executable = false;
secondary.result.binaries[4].executable = false;
const parsedSecondary = parse(JSON.stringify(secondary), "test-id");
assert.equal(parsedSecondary.installed, true);
assert.equal(parsedSecondary.shell, true);
assert.equal(parsedSecondary.server, true);
for (const key of ["login", "whoami", "version"])
    assert.equal(parsedSecondary[key], false); count++;
for (const modify of [
    x=>x.protocol=2, x=>x.request_id="stale", x=>x.ok=false,
    x=>x.error={kind:"UNKNOWN"}, x=>x.result=null,
    x=>x.result.vendor_execution="auth_transport_enabled",
    x=>x.result.probe_kind="vendor_executed", x=>x.result.auth_transport="unproven",
    x=>x.result.secret_argv=true, x=>x.result.python_mutation_fallback=true,
    x=>x.result.binaries[1].name="mega-cmd",
    x=>x.result.binaries[0].executable="true",
    x=>x.result.server_available=false, x=>x.result.binaries=[],
    // Unknown fields and non-string paths are rejected, never surfaced to UI.
    x=>x.private_token="FAKE_PRIVATE_CANARY",
    x=>delete x.error,
    x=>x.result.account_email="FAKE_PRIVATE_CANARY",
    x=>delete x.result.auth_transport,
    x=>x.result.binaries[0].private_session="FAKE_PRIVATE_CANARY",
    x=>delete x.result.binaries[0].path,
    x=>x.result.binaries[0].path={secret:"FAKE_PRIVATE_CANARY"},
    x=>x.result.binaries[0].path=42
]) {
    const x = good(); modify(x);
    assert.throws(() => parse(JSON.stringify(x), "test-id")); count++;
}
for(const [payload,id] of [
    ["not-json","test-id"], [JSON.stringify(good()),"wrong-id"],
    [JSON.stringify(good())+"\n"+JSON.stringify(good()),"test-id"],
    ["x".repeat(65537),"test-id"]
]) { assert.throws(() => parse(payload,id)); count++; }
// A preflight is opt-in and static; it must never be parsed as a live session.
const preflight = vm.runInNewContext(
    fs.readFileSync(path.join(__dirname,
        "../services/deferred/CloudStoragePreflightProtocol.js"), "utf8")
    + "\nparseConnectPreflightResponse", Object.create(null), {timeout: 2000});
const readyPreflight = () => ({
    protocol: 1, request_id: "preflight-test", ok: true, error: null,
    result: {
        adapter: "inir-mega", probe_kind: "static_connect_preflight",
        vendor_execution: "blocked_pending_disposable_qualification",
        connection_attempted: false, connected: false, auth_qualified: false,
        account_reads_enabled: false, dependencies_ready: true,
        reason: "installed_vendor_not_qualified"
    }
});
assert.equal(preflight(JSON.stringify(readyPreflight()), "preflight-test")
    .dependenciesReady, true);
const unavailablePreflight = readyPreflight();
unavailablePreflight.result.dependencies_ready = false;
unavailablePreflight.result.reason = "dependency_missing";
assert.equal(preflight(JSON.stringify(unavailablePreflight), "preflight-test")
    .dependenciesReady, false);
let preflightCases = 2;
for (const modify of [
    x=>x.request_id="preflight-old",
    x=>x.protocol=2,
    x=>x.ok=false,
    x=>x.error={kind:"FAIL"},
    x=>x.session_token="FAKE_PRIVATE_CANARY",
    x=>x.account_email="FAKE_PRIVATE_CANARY",
    x=>delete x.error,
    x=>delete x.result,
    x=>x.result.connected=true,
    x=>x.result.connection_attempted=true,
    x=>x.result.auth_qualified=true,
    x=>x.result.account_reads_enabled=true,
    x=>x.result.vendor_execution="auth_transport_enabled",
    x=>x.result.reason="ready_to_authenticate",
    x=>x.result.dependencies_ready=false,
    x=>x.result.private_path="/private/sensitive/path",
    x=>x.result.probe_kind="vendor_connected"
]) {
    const specimen = readyPreflight(); modify(specimen);
    assert.throws(() => preflight(JSON.stringify(specimen), "preflight-test"));
    preflightCases++;
}
assert.throws(() => preflight(JSON.stringify(readyPreflight())
    + JSON.stringify(readyPreflight()), "preflight-test")); preflightCases++;
assert.throws(() => preflight("x".repeat(65537), "preflight-test")); preflightCases++;
console.log("PASS MegaQML F1 vendor-free preflight parser: "
    + preflightCases + " synthetic cases");

// The next-phase catalog is an offline policy preview, never a version
// capability verdict. No installed MEGA, account data or vendor execution.
const parseGates = vm.runInNewContext(
    fs.readFileSync(path.join(__dirname,
        "../services/deferred/CloudStorageFeatureGateProtocol.js"), "utf8")
    + "\nparseOfflineFeatureGatePreview", Object.create(null), {timeout: 2000});
const domainNames = ["overview", "drive", "transfers", "sync", "backups",
    "sharing", "contacts", "mounts", "security", "preferences"];
function safePreview() {
    return {
        protocol:1, request_id:"gates-test", ok:true, error:null,
        result:{
            adapter:"inir-mega", probe_kind:"offline_policy_preview",
            vendor_execution:"blocked_pending_disposable_qualification",
            installed_version_qualified:false,
            connection_attempted:false, connected:false,
            auth_qualified:false, account_reads_enabled:false,
            writes_enabled:false,
            domains:Object.fromEntries(domainNames.map(name=>[name, {
                read:false, write:false, reason:"installed_version_unqualified"
            }]))
        }
    };
}
const gates = parseGates(JSON.stringify(safePreview()), "gates-test");
assert.equal(gates.qualified, false);
assert.equal(gates.connected, false);
assert.equal(gates.availableReadDomains.length, 0);
assert.equal(gates.availableWriteDomains.length, 0);
assert.equal(gates.reason, "installed_version_unqualified");
let gateCases = 1;
for (const mutate of [
    x=>x.protocol=2, x=>x.request_id="stale", x=>x.ok=false,
    x=>x.error={kind:"VENDOR"}, x=>x.result.probe_kind="connected",
    x=>x.result.vendor_execution="vendor_executed",
    x=>x.result.connected=true, x=>x.result.auth_qualified=true,
    x=>x.result.account_reads_enabled=true, x=>x.result.writes_enabled=true,
    x=>x.result.installed_version_qualified=true,
    x=>x.result.domains.overview.read=true,
    x=>x.result.domains.drive.write=true,
    x=>x.result.domains.security.reason="supported",
    x=>x.result.domains.overview.extra_private="/sensitive/path",
    x=>x.result.domains.extra={read:false,write:false,reason:"installed_version_unqualified"},
    x=>delete x.result.domains.contacts,
    x=>x.result.secret="PRIVATE_CAPABILITY_CANARY",
    x=>x.result=null
]) {
    const x = safePreview();
    mutate(x);
    assert.throws(() => parseGates(JSON.stringify(x), "gates-test"));
    gateCases++;
}
for (const data of ["malformed", "x".repeat(65537),
    JSON.stringify(safePreview()) + JSON.stringify(safePreview())]) {
    assert.throws(() => parseGates(data, "gates-test"));
    gateCases++;
}
console.log("PASS MegaQML denied offline capability preview: "
    + gateCases + " synthetic cases");

console.log("PASS MegaQML static protocol: "+count+" synthetic cases");
