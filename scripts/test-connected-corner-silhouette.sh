#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
node - "$repo_root/modules/common/perimeter/ConnectedSurfaceIrisFrame.qml" <<'NODE'
const assert = require('node:assert/strict');
const fs = require('node:fs');
const frame = fs.readFileSync(process.argv[2], 'utf8');

function binding(name, next) {
    const marker = `readonly property ${name}:`;
    const start = frame.indexOf(marker);
    assert.ok(start >= 0, `missing ${name} binding`);
    const end = frame.indexOf(next, start + marker.length);
    assert.ok(end > start, `unterminated ${name} binding`);
    return frame.slice(start + marker.length, end).trim();
}

const cornerJoined = new Function('root',
    `return (${binding('bool cornerJoined', '\n\n    visible:')});`);
const sdfSource = binding('rect sdfBodyRect',
    '\n\n    readonly property rect ownerShapeRect:');
assert.ok(sdfSource.startsWith('{') && sdfSource.endsWith('}'));
const sdfBodyRect = new Function('root', 'Qt', 'PerimeterTokens',
    sdfSource.slice(1, -1));
const popupShape = new Function('root',
    `return (${binding('var popupShape', '\n\n    // The shader ABI')});`);
const endJoinShape = new Function('root',
    `return (${binding('var popupEndJoinShape', '\n\n    // A box shadow')});`);

const Qt = { rect: (x, y, width, height) => ({x, y, width, height}) };
const PerimeterTokens = { irisWeldDepth: 3 };
const cases = [
    ['top', 'start', {x: 7, y: -21, width: 103, height: 108}],
    ['top', 'end', {x: 390, y: -21, width: 103, height: 108}],
    ['bottom', 'start', {x: 7, y: 313, width: 103, height: 108}],
    ['bottom', 'end', {x: 390, y: 313, width: 103, height: 108}],
    ['left', 'start', {x: -21, y: 7, width: 128, height: 83}],
    ['left', 'end', {x: -21, y: 310, width: 128, height: 83}],
    ['right', 'start', {x: 393, y: 7, width: 128, height: 83}],
    ['right', 'end', {x: 393, y: 310, width: 128, height: 83}],
];

for (const [edge, side, expected] of cases) {
    const horizontal = edge === 'top' || edge === 'bottom';
    const body = Qt.rect(
        horizontal ? (side === 'start' ? 10 : 390)
            : (edge === 'left' ? 7 : 393),
        horizontal ? (edge === 'top' ? 7 : 313)
            : (side === 'start' ? 10 : 310),
        100, 80);
    const root = {
        body, horizontal, geometry: { edge, outerRadius: 28 },
        tangentStartJoined: side === 'start',
        tangentEndJoined: side === 'end',
        fuse: 30, popupPrimaryJoins: ['owner', 'frame'],
    };
    root.cornerJoined = cornerJoined(root);
    assert.equal(root.cornerJoined, true, `${edge}/${side} joins a Screen Edge`);
    root.sdfBodyRect = sdfBodyRect(root, Qt, PerimeterTokens);
    assert.deepEqual(root.sdfBodyRect, expected,
        `${edge}/${side} must bury attached arcs under the owners`);
    const shape = popupShape(root);
    assert.equal(shape.fuse, 0,
        `${edge}/${side} must not grow a curved shoulder at Screen Edge`);
    assert.equal(shape.radius, 28,
        `${edge}/${side} retains the one free rounded corner`);
}

const center = {
    body: Qt.rect(200, 7, 100, 80), horizontal: true,
    geometry: {edge: 'top', outerRadius: 28},
    tangentStartJoined: false, tangentEndJoined: false,
    fuse: 30, popupPrimaryJoins: ['owner'],
};
center.cornerJoined = cornerJoined(center);
center.sdfBodyRect = sdfBodyRect(center, Qt, PerimeterTokens);
assert.equal(center.cornerJoined, false);
assert.deepEqual(center.sdfBodyRect, center.body,
    'popup away from output corners retains its original body geometry');
assert.equal(popupShape(center).fuse, 30,
    'popup away from output corners retains its smooth owner join');

center.tangentStartJoined = true;
center.tangentEndJoined = true;
center.cornerJoined = cornerJoined(center);
center.sdfBodyRect = sdfBodyRect(center, Qt, PerimeterTokens);
center.needsEndJoinAux = true;
assert.equal(endJoinShape(center).radius, 0,
    'a popup spanning both Screen Edges has no free corner');
assert.equal(endJoinShape(center).fuse, 0,
    'the auxiliary edge relation must not add a rounded shoulder');
assert.ok(frame.includes('root.clipExternalOwners(root.body, 0)'),
    'input stays on the original body while only the SDF reaches under owners');
console.log('connected corner silhouette: PASS (8 corners, center, both edges)');
NODE
