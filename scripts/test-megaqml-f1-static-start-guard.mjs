#!/usr/bin/env node
"use strict";
// Execute the actual QML read Process onStarted callback with deterministic
// fake process objects. No Quickshell, MEGAcmd, account or network required.
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import {fileURLToPath} from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const qml = fs.readFileSync(path.join(here,
    "../services/deferred/CloudStorageService.qml"), "utf8");
const read = qml.indexOf("id: readProc");
assert.ok(read >= 0, "real static read process missing");
const marker = "onStarted: {";
const at = qml.indexOf(marker, read);
assert.ok(at > read, "real read callback missing");
let start = at + marker.length;
let depth = 1;
let end = start;
for (; end < qml.length && depth !== 0; end++) {
    if (qml[end] === "{") depth++;
    else if (qml[end] === "}") depth--;
}
assert.equal(depth, 0, "unbalanced real QML callback");
const callback = new Function("root", "readProc", qml.slice(start, end - 1));

function observe(overrides) {
    const writes = [], signals = [];
    const root = Object.assign({
        readBusy: true, consumerCount: 1, generation: 4,
        _pendingGeneration: 4, _pendingInput: '{"FAKE_ONLY":true}\\n'
    }, overrides);
    const readProc = {
        startObserved: false, stdinEnabled: true,
        signal(code) { signals.push(code); },
        write(value) { writes.push(value); }
    };
    callback(root, readProc);
    assert.equal(readProc.startObserved, true);
    return {root, readProc, writes, signals};
}
const active = observe({});
assert.equal(active.writes.length, 1, "active current lease must dispatch once");
assert.equal(active.writes[0], '{"FAKE_ONLY":true}\\n');
assert.deepEqual(active.signals, []);
assert.equal(active.root._pendingInput, "");
assert.equal(active.readProc.stdinEnabled, false);
for (const [name, change] of [
    ["hidden", {consumerCount: 0}],
    ["stale-generation", {_pendingGeneration: 3}],
    ["not-busy", {readBusy: false}],
    ["empty-input", {_pendingInput: ""}]
]) {
    const result = observe(change);
    assert.deepEqual(result.writes, [], name + ": stale request was sent");
    assert.deepEqual(result.signals, [9], name + ": stale child not terminated");
    assert.equal(result.root._pendingInput, "", name + ": stale input retained");
}
console.log("PASS F1 static delayed-start guard fake-only lifecycle cases");
