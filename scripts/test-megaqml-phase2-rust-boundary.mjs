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
    console.log("PASS MegaQML fake-PATH Rust-to-QML static boundary: " + cases + " cases");
} finally {
    fs.rmSync(dir, {recursive:true, force:true});
}
