#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
bash -n "$repo_root/scripts/capture-windows.sh"
node - "$repo_root/services/WindowPreviewService.qml" "$repo_root/services/WindowPreviewPolicy.js" "$repo_root/scripts/capture-windows.sh" <<'NODE'
const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const service = fs.readFileSync(process.argv[2], 'utf8');
const policy = {};
vm.createContext(policy);
vm.runInContext(fs.readFileSync(process.argv[3], 'utf8'), policy);
const shell = fs.readFileSync(process.argv[4], 'utf8');
const ready = shell.indexOf("printf 'PREVIEW_READY %s\\n' \"$id\"");
const clipboardCleanup = shell.indexOf('preview_hashes=()');
assert.ok(ready > 0 && ready < clipboardCleanup, 'publish must precede batch clipboard cleanup');
assert.ok(shell.includes('wait "$pid" || capture_failed=1'), 'partial screenshot failure must propagate');

function method(name) {
    const at = service.indexOf('function ' + name + '(');
    assert.ok(at >= 0, 'missing service method: ' + name);
    const brace = service.indexOf('{', at);
    let nesting = 0;
    for (let i = brace; i < service.length; i++) {
        if (service[i] === '{') nesting++;
        if (service[i] === '}' && --nesting === 0) {
            return service.slice(at, i + 1)
                .replace(/:\s*(?:int|real|var|bool|string|void)\b/g, '');
        }
    }
    throw Error('unclosed function: ' + name);
}
const root = {
    previewDir: '/preview', sessionKey: 'session-a',
    initialized: false, sessionReady: false, capturing: false,
    forceRefreshRequestedWhileInitializing: false,
    observedWindowIds: [], captureAllRequested: false, requestedWindowIds: [],
    captureRequestedWhileInitializing: false,
    previewCache: {}, overviewWarmRequestedIds: [], overviewWarmImages: {},
    overviewWarmOrder: [], overviewWarmLimit: 2,
    previewUpdates: [], complete: 0, warmed: [],
    initialize() { this.initialized = true; },
    captureComplete() { this.complete++; },
    previewUpdated(id) { this.previewUpdates.push(id); },
    _touchOverviewWarmImage(id) { this.warmed.push(id); },
    cleanupOrphans() {}, _log() {}
};
let scheduled = 0, cleanupScheduled = 0, created = 0;
const captureProcess = {
    idsToCapture: [], publishedIds: [], captureSessionKey: '',
    running: false, command: []
};
const ctx = {
    root, PreviewPolicy: policy, captureProcess,
    CompositorService: {isNiri: true},
    NiriService: {windowListReady: false, windows: []},
    captureDebounceTimer: {restart() {scheduled++;}},
    cleanupTimer: {restart() {cleanupScheduled++;}},
    Cliphist: {suppressRefresh: false, refresh() {}},
    ShellExec: {supportsFish: () => false},
    Quickshell: {shellPath: path => path},
    console
};
for (const name of ['previewDir', 'sessionKey', 'initialized', 'sessionReady',
    'capturing', 'observedWindowIds','captureAllRequested','requestedWindowIds',
    'captureRequestedWhileInitializing','forceRefreshRequestedWhileInitializing',
    'previewCache', 'overviewWarmRequestedIds', 'overviewWarmLimit']) {
    Object.defineProperty(ctx, name, {
        get() { return root[name]; },
        set(value) { root[name] = value; }
    });
}
ctx._log = root._log;
vm.createContext(ctx);
const names = ['_startPrewarming','_observeWindowSet','_queueWindowIds',
    '_hasPendingCaptureRequest','_clearCaptureRequest','_pendingRequestNeedsCapture',
    'captureForTaskView','captureAllWindows','_doCapture','_publishCapturedPreview',
    '_handleCaptureOutput','_completeCapture','_primeCachedPreviews',
    'getPreviewUrl','_resumeRequestedCapture'];
vm.runInContext(names.map(method).join('\n') + '\n' +
    names.map(name => 'root.' + name + ' = ' + name + ';').join('\n'), ctx);

root._startPrewarming();
assert.equal(root.initialized, true, 'service initializes before hover');
assert.equal(scheduled, 0, 'initial unknown window list cannot trigger capture');
ctx.NiriService.windowListReady = true;
ctx.NiriService.windows = [{id: 11}, {id: 12}];
root._observeWindowSet();
assert.equal(root.captureRequestedWhileInitializing, true, 'new windows queued during init');
assert.deepEqual(Array.from(root.requestedWindowIds), [11,12]);
root.sessionReady = true;
root._resumeRequestedCapture();
root._doCapture();
assert.deepEqual(Array.from(captureProcess.idsToCapture), [11,12],
    'first batch includes both new IDs before Overview is opened');
assert.equal(root.previewUpdates.length, 0, 'no false publication before rename');
root.overviewWarmRequestedIds = [];
root._handleCaptureOutput('PREVIEW_READY 11');
const first = root.getPreviewUrl(11);
assert.equal(first, 'file:///preview/window-11.png?' + root.previewCache[11].timestamp,
    'first capture becomes visible while process still running');
assert.deepEqual(root.previewUpdates, [11]);
assert.deepEqual(root.warmed, [11], 'new preview is decoded before first hover');
assert.equal(root.capturing, true, 'one window ready does not wait for whole batch');
root._handleCaptureOutput('PREVIEW_READY 11');
root._handleCaptureOutput('PREVIEW_READY 999');
root._handleCaptureOutput('PREVIEW_READY 0');
assert.deepEqual(root.previewUpdates, [11], 'duplicates and unrequested IDs rejected');
ctx.NiriService.windows = [{id:11},{id:12},{id:13}];
root._observeWindowSet();
assert.deepEqual(Array.from(root.requestedWindowIds), [13],
    'new window arriving during capture stays queued for next batch');
root._handleCaptureOutput('PREVIEW_READY 12');
assert.deepEqual(root.previewUpdates, [11,12], 'second PNG independently published');
const warmedBeforeScan = root.warmed.length;
root._primeCachedPreviews();
assert.ok(root.warmed.length > warmedBeforeScan,
    'session-matched disk cache is proactively decoded');
root._completeCapture(0, null);
assert.deepEqual(root.previewUpdates, [11,12], 'clean exit does not duplicate a published ID');
root._doCapture();
assert.deepEqual(Array.from(captureProcess.idsToCapture), [13],
    'in-flight new window is captured after prior batch');
// The last completion line may still be buffered at process exit.
root._completeCapture(0, null);
assert.deepEqual(root.previewUpdates, [11,12,13], 'clean exit publishes buffered final ID');
const stable = root.getPreviewUrl(11);
root.captureForTaskView([11]);
assert.equal(root.getPreviewUrl(11), stable, 'long-idle cache hit keeps URL');
root.capturing = false;
root.previewCache[11].timestamp = policy.nextRevision(root.previewCache[11].timestamp, 1);
assert.notEqual(root.getPreviewUrl(11), stable, 'explicit refresh advances URL revision');
root.capturing = true;
captureProcess.idsToCapture = [12];
captureProcess.publishedIds = [];
root._handleCaptureOutput('PREVIEW_READY 11');
assert.equal(root.previewUpdates.length, 3, 'stale batch output cannot publish');
captureProcess.captureSessionKey = 'session-old';
root._handleCaptureOutput('PREVIEW_READY 12');
assert.equal(root.previewUpdates.length, 3, 'old Niri session output cannot publish');
root._completeCapture(1, 'failure');
assert.equal(root.previewUpdates.length, 3,
    'failed batch must not mark an old snapshot as new');
console.log('window preview eager/incremental behavior: PASS');
NODE
