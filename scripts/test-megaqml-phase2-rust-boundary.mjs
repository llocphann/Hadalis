#!/usr/bin/env node
// Direct Rust detect -> QML pure-parser integration. Temporary fake PATH only.
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import {spawnSync} from "node:child_process";
import {fileURLToPath} from "node:url";
import vm from "node:vm";

const here = path.dirname(fileURLToPath(import.meta.url));
const bin = path.resolve(process.argv[2] ?? "");
assert.ok(fs.statSync(bin).isFile(), "Rust binary unavailable");
const parse = vm.runInNewContext(
    fs.readFileSync(path.resolve(here, "../services/deferred/CloudStorageStaticProtocol.js"), "utf8")
    + "\nparseDetectResponse", Object.create(null), {timeout: 2000});
const dir = fs.mkdtempSync(path.join(os.tmpdir(), "megaqml-fake-bin-"));
let cases = 0;
try {
    function detect(id) {
        const request = JSON.stringify({protocol:1, request_id:id, operation:"detect",params:{}}) + "\n";
        const child = spawnSync(bin, ["request"], {
            input:request, encoding:"utf8", timeout:6000, maxBuffer:65536, shell:false,
            env:{PATH:dir, LANG:"C", LC_ALL:"C"}
        });
        assert.equal(child.error, undefined, "Rust detection transport");
        assert.equal(child.status, 0, "Rust detection exit");
        return parse(child.stdout, id);
    }
    const missing = detect("boundary-1");
    assert.equal(missing.installed, false);
    assert.equal(missing.shell, false);
    assert.equal(missing.server, false);
    for (const key of ["login", "whoami", "version"])
        assert.equal(missing[key], false);
    cases++;
    for (const name of ["mega-cmd", "mega-cmd-server"]) {
        const fake = path.join(dir, name);
        // If execution regresses, the marker proves it. Never invoke this script intentionally.
        fs.writeFileSync(fake, "#!/bin/sh\nprintf unexpected > \"$0.executed\"\n", {mode:0o700});
        fs.chmodSync(fake, 0o700);
    }
    const present = detect("boundary-2");
    assert.equal(present.installed, true);
    assert.equal(present.shell, true);
    assert.equal(present.server, true);
    for (const key of ["login", "whoami", "version"])
        assert.equal(present[key], false);
    for (const name of ["mega-cmd", "mega-cmd-server"])
        assert.equal(fs.existsSync(path.join(dir, name + ".executed")), false);
    cases++;
    fs.chmodSync(path.join(dir, "mega-cmd-server"), 0o600);
    const partial = detect("boundary-3");
    assert.equal(partial.installed, false);
    assert.equal(partial.shell, true);
    assert.equal(partial.server, false);
    cases++;
    // F1 preflight runs only after an explicit typed request. It must be
    // static in BOTH missing and installed-looking fake-PATH environments.
    const preflightParser = vm.runInNewContext(
        fs.readFileSync(path.resolve(here,
            "../services/deferred/CloudStoragePreflightProtocol.js"), "utf8")
        + "\nparseConnectPreflightResponse", Object.create(null), {timeout: 2000});
    function preflight(id, patch={}) {
        const request = JSON.stringify({
            protocol:1, request_id:id, operation:"connect_preflight",
            params:{}, ...patch
        }) + "\n";
        const child = spawnSync(bin, ["request"], {
            input:request, encoding:"utf8", timeout:6000, maxBuffer:65536,
            shell:false, env:{PATH:dir, LANG:"C", LC_ALL:"C"}
        });
        assert.equal(child.error, undefined);
        assert.equal(child.status, 0);
        return child.stdout;
    }
    const partialPreflight = preflightParser(preflight("preflight-partial"),
        "preflight-partial");
    assert.equal(partialPreflight.dependenciesReady, false); cases++;
    fs.chmodSync(path.join(dir, "mega-cmd-server"), 0o700);
    const readyPreflight = preflightParser(preflight("preflight-ready"),
        "preflight-ready");
    assert.equal(readyPreflight.dependenciesReady, true);
    assert.equal(readyPreflight.reason, "installed_vendor_not_qualified");
    assert.equal(fs.existsSync(path.join(dir, "mega-cmd.executed")), false);
    assert.equal(fs.existsSync(path.join(dir, "mega-cmd-server.executed")), false);
    cases++;
    for (const input of [
        {secret: {password:"PRIVATE_FAKE_SECRET_CANARY"}},
        {params: {raw_command:"mega-rm"}}
    ]) {
        const payload = preflight("preflight-rejected", input);
        const response = JSON.parse(payload);
        assert.equal(response.ok, false);
        assert.equal(response.error.kind, "PREFLIGHT_INPUT_FORBIDDEN");
        assert.equal(response.error.outcome, "not_dispatched");
        assert.equal(payload.includes("PRIVATE_FAKE_SECRET_CANARY"), false);
        assert.throws(() => preflightParser(payload, "preflight-rejected"));
        cases++;
    }
    assert.equal(fs.existsSync(path.join(dir, "mega-cmd.executed")), false);
    assert.equal(fs.existsSync(path.join(dir, "mega-cmd-server.executed")), false);

    // Next-phase staging: the protocol can describe all 10 domains but
    // never confuses offline policy with installed-version proof. Fake PATH
    // includes executable-looking shells that MUST NOT be launched.
    function preview(id, patch={}) {
        const request = JSON.stringify({
            protocol:1, request_id:id, operation:"feature_gates_preview",
            params:{}, ...patch
        }) + "\n";
        const child = spawnSync(bin, ["request"], {
            input:request, encoding:"utf8", timeout:6000, maxBuffer:65536,
            shell:false, env:{PATH:dir, LANG:"C", LC_ALL:"C"}
        });
        assert.equal(child.error, undefined);
        assert.equal(child.status, 0);
        return child.stdout;
    }
    const previewPayload = JSON.parse(preview("gates-preview"));
    assert.equal(previewPayload.ok, true);
    assert.equal(previewPayload.request_id, "gates-preview");
    assert.equal(previewPayload.error, null);
    const gates = previewPayload.result;
    assert.equal(gates.probe_kind, "offline_policy_preview");
    assert.equal(gates.vendor_execution,
        "blocked_pending_disposable_qualification");
    for (const flag of ["installed_version_qualified",
        "connection_attempted", "connected", "auth_qualified",
        "account_reads_enabled", "writes_enabled"])
        assert.equal(gates[flag], false);
    assert.deepEqual(Object.keys(gates.domains).sort(), [
        "overview", "drive", "transfers", "sync", "backups",
        "sharing", "contacts", "mounts", "security", "preferences"
    ].sort());
    for (const entry of Object.values(gates.domains)) {
        assert.equal(entry.read, false);
        assert.equal(entry.write, false);
        assert.equal(entry.reason, "installed_version_unqualified");
    }
    cases++;
    for (const patch of [
        {secret:{password:"PRIVATE_FAKE_GATE_PASSWORD"}},
        {secret:{}},
        {params:{enable_live:true, account:"PRIVATE_FAKE_GATE_ACCOUNT"}}
    ]) {
        const payload = preview("gates-reject", patch);
        const result = JSON.parse(payload);
        assert.equal(result.ok, false);
        assert.equal(result.error.kind, "FEATURE_GATE_INPUT_FORBIDDEN");
        assert.equal(result.error.outcome, "not_dispatched");
        assert.equal(payload.includes("PRIVATE_FAKE_GATE_"), false);
        cases++;
    }
    for (const name of ["mega-cmd", "mega-cmd-server"])
        assert.equal(fs.existsSync(path.join(dir, name + ".executed")), false);

    // Bad JSON enum values can carry secret-like strings in serde errors;
    // the production binary must emit only a fixed, never-raw diagnostic.
    const invalid = spawnSync(bin, ["request"], {
        input:JSON.stringify({
            protocol:1, request_id:"invalid-op",
            operation:"PRIVATE_PARSE_CANARY", params:{}
        }) + "\n",
        encoding:"utf8", timeout:6000, maxBuffer:65536, shell:false,
        env:{PATH:dir, LANG:"C", LC_ALL:"C"}
    });
    assert.equal(invalid.status, 2);
    assert.equal(JSON.parse(invalid.stdout).error.kind, "INVALID_REQUEST");
    assert.equal((invalid.stdout + invalid.stderr).includes("PRIVATE_PARSE_CANARY"), false);
    cases++;

    console.log("PASS MegaQML fake-PATH Rust-to-QML static boundary: " + cases + " cases");
} finally {
    fs.rmSync(dir, {recursive:true, force:true});
}
