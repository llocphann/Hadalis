// Behavior tests for the semantic renderer vocabulary, not drawing spelling.
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const path = require("node:path");
const root = path.resolve(__dirname, "..");
const source = fs.readFileSync(path.join(root, "modules/abyss/companion/WullExpressions.js"), "utf8");
const api = vm.createContext({});
vm.runInContext(source.replace(/^\.pragma library\s*/u, ""), api);
const names = ["idle", "happy", "excited", "thinking", "working", "surprised", "sleepy", "sad", "alert"];
assert.deepEqual(Array.from(api.names), names);
for (const name of names) {
    assert.equal(api.resolve(name, "sleepy", "error"), name);
    assert.equal(api.profile(name).name, name);
    assert.ok(api.profile(name).energy >= 0 && api.profile(name).energy <= 1);
}
assert.equal(api.resolve("", "happy", "working"), "working");
assert.equal(api.resolve(null, "calm", "error"), "sad");
assert.equal(api.resolve(undefined, "calm", "warning"), "alert");
assert.equal(api.resolve("unknown", "curious", "idle"), "thinking");
assert.equal(api.resolve("unknown", "sleepy", "idle"), "sleepy");
assert.equal(api.resolve("run_command", "unknown", "unknown"), "idle");
assert.ok(api.profile("happy").smilingEyes);
assert.ok(api.profile("working").closedEyes && api.profile("working").orbit);
assert.ok(api.profile("sleepy").closedEyes);
assert.ok(api.profile("surprised").openMouth);
assert.ok(api.profile("sad").worried);
assert.ok(api.profile("excited").energy > api.profile("idle").energy);
const bridge = fs.readFileSync(path.join(root, "modules/abyss/companion/CompanionBridge.qml"), "utf8");
const sendIntent = bridge.match(/    function sendIntent\([\s\S]*?\n    \}/u)?.[0];
assert.ok(sendIntent, "public bridge intent API");
const writes = [];
api.Expressions = api;
api.root = { backendEnabled: true, ready: true, outboundSeq: 0 };
api.backendProcess = { running: true, write: line => writes.push(line) };
vm.runInContext(sendIntent, api);
for (const args of [
    ["run_command", 0.5, 1000], ["happy", NaN, 1000],
    ["happy", Infinity, 1000], ["happy", "0.5", 1000],
    ["happy", -0.1, 1000], ["happy", 1.1, 1000],
    ["happy", 0.5, 249], ["happy", 0.5, 10001], ["happy", 0.5, 1000.5]
]) {
    assert.equal(api.sendIntent(...args), false);
    assert.equal(api.root.outboundSeq, 0);
}
for (const name of names) {
    assert.equal(api.sendIntent(name, 0.45, 1600), true);
    const record = JSON.parse(writes.at(-1));
    assert.equal(record.seq, writes.length);
    assert.deepEqual(record, {
        v: 1, seq: writes.length, type: "intent",
        expression: name, intensity: 0.45, ttl_ms: 1600
    });
    assert.ok(writes.at(-1).endsWith("\n"));
}
for (const [object, flag] of [[api.root, "ready"], [api.root, "backendEnabled"], [api.backendProcess, "running"]]) {
    object[flag] = false;
    assert.equal(api.sendIntent("happy", 0.5, 1000), false);
    object[flag] = true;
    assert.equal(writes.length, 9);
}
console.log("WULL_NINE_EXPRESSION_AND_BRIDGE_BEHAVIOR_PASS");
