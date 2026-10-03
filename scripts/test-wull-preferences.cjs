const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const path = require("node:path");
const directory = path.resolve(__dirname, "../modules/abyss/companion");
const api = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(directory, "WullPreferences.js"), "utf8").replace(/^\.pragma library\s*/u, ""), api);
const plain = value => JSON.parse(JSON.stringify(value));
const defaults = require("../defaults/config.json").abyss.companion;
assert.deepEqual(plain(api.defaults()), defaults);
assert.deepEqual(plain(api.normalize()), defaults);
const invalid = api.normalize({
    enabled: "true", output: [], edge: "diagonal", along: NaN, size: Infinity,
    interactive: "false", personality: "run_command", appearanceFrequency: "once",
    animationsEnabled: 0, effectsEnabled: null, hideInFullscreen: "true", renderQuality: "ultra"
});
assert.deepEqual(plain(invalid), defaults);
for (const [field, min, max] of [["size", 0.65, 1.5], ["along", 0.08, 0.92], ["translucency", 0, 0.35]]) {
    assert.equal(api.normalize({[field]: -10})[field], min);
    assert.equal(api.normalize({[field]: 20})[field], max);
    for (const value of [NaN, Infinity, -Infinity, null, "NaN", "1"])
        assert.equal(api.normalize({[field]: value})[field], defaults[field]);
}
assert.equal(api.motionScale("calm"), 0.55);
assert.equal(api.motionScale("balanced"), 1);
assert.equal(api.motionScale("energetic"), 1.35);
assert.equal(api.motionScale("unknown"), 1);
for (const [index, quality] of Array.from(api.qualities).entries()) {
    assert.equal(api.normalize({renderQuality: quality}).renderQuality, quality);
    assert.equal(api.renderTier(quality, "balanced"), index);
    assert.equal(api.renderTier(quality, "quality"), index);
    assert.equal(api.renderTier(quality, "performance"), 0);
}
assert.equal(api.renderTier("unknown", "balanced"), 1);
const bridge = fs.readFileSync(path.join(directory, "CompanionBridge.qml"), "utf8");
for (const name of ["boundedNumber", "sendEvent", "sendPreferences", "acceptLine"]) {
    const body = bridge.match(new RegExp("    function " + name + "\\([\\s\\S]*?\\n    \\}", "u"))?.[0];
    assert.ok(body, name);
    vm.runInContext(body, api);
}
const writes = [];
api.Preferences = api;
api.Expressions = { resolve: expression => expression || "idle" };
api.backendProcess = { running: true, write: line => writes.push(JSON.parse(line)) };
api.stableConnectionTimer = { restart() {} };
const callbacks = [];
api.Qt = { callLater: callback => callbacks.push(callback) };
api.root = {
    backendEnabled: true, ready: false, requestedVisible: true, inboundSeq: 0, outboundSeq: 0,
    personality: "energetic", appearanceFrequency: "occasional", stateAccepted() {},
    boundedNumber: api.boundedNumber, sendPreferences: api.sendPreferences, sendEvent: api.sendEvent
};
assert.equal(api.sendPreferences(), false);
api.acceptLine(JSON.stringify({v: 1, seq: 1, type: "state", visibility: "hidden", expression: "idle"}));
assert.equal(api.root.ready, true);
assert.equal(writes.length, 0);
callbacks.shift()();
assert.deepEqual(writes, [
    {v: 1, seq: 1, type: "preferences", personality: "energetic", appearance_frequency: "occasional"},
    {v: 1, seq: 2, type: "event", event: "show"}
]);
for (const personality of api.personalities) for (const frequency of api.frequencies) {
    api.root.personality = personality;
    api.root.appearanceFrequency = frequency;
    assert.equal(api.sendPreferences(), true);
    assert.equal(writes.at(-1).personality, personality);
    assert.equal(writes.at(-1).appearance_frequency, frequency);
    assert.equal(writes.at(-1).seq, writes.length);
}
for (const [object, field, value] of [
    [api.root, "personality", "hyper"], [api.root, "appearanceFrequency", "weekly"],
    [api.root, "backendEnabled", false], [api.root, "ready", false], [api.backendProcess, "running", false]
]) {
    const previous = object[field], count = writes.length, sequence = api.root.outboundSeq;
    object[field] = value;
    assert.equal(api.sendPreferences(), false);
    assert.equal(api.root.outboundSeq, sequence);
    assert.equal(writes.length, count);
    object[field] = previous;
}
// A queued handshake observes the current show permission, including a hide
// or disable that occurred after stdout arrived but before callLater runs.
for (const disable of [false, true]) {
    api.root.ready = false;
    api.root.requestedVisible = false;
    api.acceptLine(JSON.stringify({v: 1, seq: api.root.inboundSeq + 1, type: "state"}));
    if (disable) api.root.backendEnabled = false;
    const count = writes.length;
    callbacks.shift()();
    assert.equal(writes.length, count + (disable ? 0 : 1));
    if (!disable) assert.equal(writes.at(-1).type, "preferences");
    api.root.backendEnabled = true;
}
console.log("WULL_PREFERENCES_NORMALIZATION_AND_BRIDGE_BEHAVIOR_PASS");
