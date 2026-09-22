#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
node - "$repo_root/services/WindowPreviewService.qml" "$repo_root/services/WindowPreviewPolicy.js" <<'NODE'
const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const service = fs.readFileSync(process.argv[2], 'utf8');
const policy = fs.readFileSync(process.argv[3], 'utf8');
const p = {};
vm.createContext(p);
vm.runInContext(policy, p);

// Run the actual service method bodies with Process/Image/clock mock objects;
// a spelling grep cannot pass these initial/idle/refresh/teardown assertions.
const methods = [
    '_queueWindowIds', '_hasPendingCaptureRequest', '_clearCaptureRequest',
    '_pendingRequestNeedsCapture', 'captureForTaskView', '_doCapture',
    'captureAllWindows', 'getPreviewUrl', 'cleanupOrphans',
    '_dropOverviewWarmImage', '_clearOverviewWarmImages',
    '_touchOverviewWarmImage', '_syncOverviewWarmImages', 'warmForOverview',
    '_completeSessionReset', '_resumeRequestedCapture', 'clearPreviews'
];
function extract(name) {
    const token = 'function ' + name + '(';
    const start = service.indexOf(token);
    assert.ok(start >= 0, 'missing actual service method: ' + name);
    const brace = service.indexOf('{', start);
    let depth = 0, end = -1;
    for (let i = brace; i < service.length; i++) {
        if (service[i] === '{') depth++;
        if (service[i] === '}' && --depth === 0) { end = i + 1; break; }
    }
    assert.ok(end > brace, 'unclosed service method: ' + name);
    return service.slice(start, end)
        .replace(/:\s*(?:int|real|var|bool|string|void)\b/g, '');
}
let scheduled = 0, captures = 0, destroyed = 0, created = 0, completed = 0;
const root = {
    initialized: true, sessionReady: true, capturing: false,
    captureAllRequested: false, requestedWindowIds: [],
    captureRequestedWhileInitializing: false, previewCache: {},
    overviewWarmImages: {}, overviewWarmOrder: [],
    overviewWarmRequestedIds: [], overviewWarmLimit: 2,
    previewDir: '/tmp/previews', sessionKey: 'current-socket',
    _log() {}, initialize() { this.initialized = true; },
    captureComplete() { completed++; }, previewUpdated() {}
};
const scope = {
    root, PreviewPolicy: p, NiriService: {windowListReady: true, windows: [{id: 11}, {id: 12}]},
    captureDebounceTimer: {restart() {scheduled++;}},
    captureProcess: {idsToCapture: [], command: [], running: false},
    Cliphist: {suppressRefresh: false},
    ShellExec: {supportsFish: () => false},
    Quickshell: {shellPath: path => path, execDetached() {}},
    overviewWarmImageComponent: {createObject(_parent, properties) {
        created++; return {source: properties.source, destroy() {destroyed++;}};
    }},
    sessionFileView: {setText(value) {root.marker = value;}},
    console
};
// Mirror QML's unqualified singleton properties in the behavior harness.
scope._log = root._log;
for (const key of ['previewCache','requestedWindowIds','captureAllRequested',
    'capturing','initialized','sessionReady','captureRequestedWhileInitializing',
    'overviewWarmImages','overviewWarmOrder','overviewWarmRequestedIds',
    'overviewWarmLimit','previewDir','sessionKey']) {
    Object.defineProperty(scope, key, {
        get() { return root[key]; },
        set(value) { root[key] = value; },
        configurable: true
    });
}
vm.createContext(scope);
vm.runInContext(methods.map(extract).join('\n') +
    '\n' + methods.map(n => 'root.' + n + ' = ' + n + ';').join('\n'), scope);
// QML's unqualified property names resolve to the same backing properties;
// synchronize them in the lightweight mock after a method replaces an array.
function sync() {
    for (const key of ['previewCache','requestedWindowIds','captureAllRequested',
        'capturing','initialized','sessionReady','overviewWarmImages',
        'overviewWarmOrder','overviewWarmRequestedIds']) scope[key] = root[key];
}
root.captureForTaskView([11]); sync();
assert.equal(scheduled, 1, 'first missing preview schedules capture');
root._doCapture(); sync();
assert.equal(scope.captureProcess.running, true, 'first visit starts Process');
assert.deepEqual(Array.from(scope.captureProcess.idsToCapture), [11]);
root.capturing = false;
root.previewCache[11] = {path: '/tmp/previews/window-11.png', timestamp: 1};
sync();
const stable = root.getPreviewUrl(11);
root.captureForTaskView([11]); sync();
assert.equal(scheduled, 1, 'long-idle cached hit does not schedule capture');
assert.equal(root.getPreviewUrl(11), stable, 'cache hit never changes URL');
root.captureAllWindows(); sync();
assert.equal(scope.captureProcess.running, true, 'force refresh starts Process');
assert.ok(scope.captureProcess.command.includes('11')
    && scope.captureProcess.command.includes('12'),
    'force refresh requests the exact live window IDs');
root.capturing = false;
root.previewCache[11].timestamp = p.nextRevision(1, 1);
assert.notEqual(root.getPreviewUrl(11), stable, 'force refresh produces a new URL revision');
root.warmForOverview([11,11,12]); sync();
assert.equal(created, 1, 'only existing visible previews warm');
root.warmForOverview([11]); sync();
assert.equal(created, 1, 'reopening retains previously decoded Image object');
root.previewCache[12] = {path: '/tmp/previews/window-12.png', timestamp: 1};
root.warmForOverview([11,12]); sync();
assert.equal(created, 2, 'second preview warms into resident budget');
root.previewCache[13] = {path: '/tmp/previews/window-13.png', timestamp: 1};
root.warmForOverview([12,13]); sync();
assert.equal(Object.keys(root.overviewWarmImages).length, 2, 'LRU budget is enforced');
assert.ok(!root.overviewWarmImages[11], 'old window is evicted');
scope.NiriService.windows = [{id: 13}];
root.cleanupOrphans(); sync();
assert.ok(!root.previewCache[11] && !root.previewCache[12], 'closed windows are purged');
assert.ok(!root.overviewWarmImages[12], 'closed window decoded image is purged');
root._completeSessionReset(); sync();
assert.deepEqual(Object.keys(root.previewCache), [], 'new session drops disk mapping');
assert.deepEqual(Object.keys(root.overviewWarmImages), [], 'new session releases decoded images');
assert.equal(root.marker, 'current-socket\n', 'new session marker is written');
assert.ok(completed > 0 && destroyed > 0, 'lifecycle notifications and releases occur');
console.log('window preview service lifecycle behavior: PASS');
NODE
