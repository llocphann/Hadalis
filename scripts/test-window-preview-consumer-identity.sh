#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
node - "$repo_root" <<'NODE'
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const rootDir = process.argv[2];
const consumers = [
    ['modules/dock/DockWindowPreview.qml', 'previewArea'],
    ['modules/bar/BarTaskbarWindowPreview.qml', 'previewArea'],
    ['modules/waffle/taskview/WindowThumbnail.qml', 'previewArea'],
    ['modules/waffle/bar/tasks/WindowPreview.qml', 'root'],
    ['modules/altSwitcher/AltSwitcher.qml', 'modelData'],
    ['modules/waffle/altSwitcher/WaffleAltSwitcherContent.qml', 'modelData']
];
for (const [file, owner] of consumers) {
    const content = fs.readFileSync(path.join(rootDir, file), 'utf8');
    const marker = 'readonly property string previewUrl: {';
    const index = content.indexOf(marker);
    assert.ok(index >= 0, file + ': preview must be a reactive QML binding');
    const bodyStart = index + marker.length;
    const bodyEnd = content.indexOf('}', bodyStart);
    assert.ok(bodyEnd > bodyStart, file + ': unterminated preview binding');
    const source = content.slice(bodyStart, bodyEnd);
    assert.ok(source.includes('WindowPreviewService.previewCache['),
        file + ': preview binding must observe cache reset/revision');
    const preview = new Function('WindowPreviewService', 'previewArea', 'root',
        'modelData', source);
    const api = {
        previewCache: {},
        getPreviewUrl(id) {
            const cached = this.previewCache[id];
            return cached ? 'file://' + cached.path + '?' + cached.timestamp : '';
        }
    };
    const previewArea = {windowId: 11};
    const root = {niriWindowId: 11};
    const modelData = {id: 11};
    function read() { return preview(api, previewArea, root, modelData); }
    assert.equal(read(), '', file + ': first miss');
    api.previewCache = {11: {path: '/cache/window-11.png', timestamp: 1}};
    const stable = read();
    assert.equal(stable, 'file:///cache/window-11.png?1', file + ': first capture');
    assert.equal(read(), stable, file + ': idle/cache hit preserves URL');
    api.previewCache = {11: {path: '/cache/window-11.png', timestamp: 2}};
    assert.equal(read(), 'file:///cache/window-11.png?2', file + ': force revision');
    api.previewCache[12] = {path: '/cache/window-12.png', timestamp: 3};
    if (owner === 'previewArea') previewArea.windowId = 12;
    else if (owner === 'root') root.niriWindowId = 12;
    else modelData.id = 12;
    assert.equal(read(), 'file:///cache/window-12.png?3',
        file + ': delegate rebinds to exact window identity');
    api.previewCache = {};
    assert.equal(read(), '', file + ': close/session reset clears stale URL');
}
console.log('window preview consumer identity behavior: PASS');
NODE
