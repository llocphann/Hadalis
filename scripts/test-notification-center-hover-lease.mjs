#!/usr/bin/env node
// Evaluate the actual NotificationCenterPopup QML property expressions.
// Regression: source HoverHandler can remain true after the anchor MouseArea
// reports containsMouse=false; notification lease must NOT expire at that point.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const project = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const source = readFileSync(resolve(project,
    'modules/notificationCenter/NotificationCenterPopup.qml'), 'utf8');
const styled = readFileSync(resolve(project,
    'modules/bar/StyledPopup.qml'), 'utf8');

function propExpression(src, property, next) {
    const startToken = 'readonly property bool ' + property + ':';
    const endToken = '\n    ' + next;
    const start = src.indexOf(startToken);
    assert.ok(start >= 0, 'Missing property ' + property);
    const begin = start + startToken.length;
    const end = src.indexOf(endToken, begin);
    assert.ok(end >= 0, 'Missing expression boundary for ' + property);
    return src.slice(begin, end).trim();
}
const anchorExpression = propExpression(source, '_anchorHovered',
    'readonly property bool hoverLeaseRequested:');
const leaseExpression = propExpression(source, 'hoverLeaseRequested',
    'hoverTarget:');
// These are expressions taken from QML, not test-side restatements of policy.
const anchorFn = new Function('root', 'return (' + anchorExpression + ');');
const leaseFn = new Function('root', 'contentLoader',
    'return (' + leaseExpression + ');');

assert.match(styled, /property Item _anchorHover: Item\s*\{/);
assert.match(styled, /readonly property bool hovered: sourceHover\.hovered/);
assert.match(source, /onHoverLeaseRequestedChanged:\s*\{[\s\S]*?if \(root\.hoverLeaseRequested\)\s*\{[\s\S]*?exitGraceTimer\.stop\(\)/);

const base = {
    anchorItem: { containsMouse: false },
    _anchorHover: { hovered: false },
    hoverAllowed: true,
    explicitForThisOutput: false,
    presentationActive: true,
    popupHovered: false,
    entryBridgeHeld: false,
};
let assertions = 3;
function check(label, root, expectedAnchor, expectedLease) {
    const anchored = anchorFn(root);
    assert.equal(anchored, expectedAnchor, label + ': anchor');
    const state = { ...root, _anchorHovered: anchored };
    assert.equal(leaseFn(state, { item: null }), expectedLease, label + ': lease');
    assertions += 2;
}
check('neither source owns hover', base, false, false);
check('MouseArea-only hover', { ...base, anchorItem: { containsMouse: true } }, true, true);
check('HoverHandler-only hover (actual owner contradiction)',
    { ...base, _anchorHover: { hovered: true } }, true, true);
check('both sources hovered',
    { ...base, anchorItem: { containsMouse: true },
        _anchorHover: { hovered: true } }, true, true);
check('pointer gone releases lease', base, false, false);
check('hover disabled does not request lease',
    { ...base, hoverAllowed: false, _anchorHover: { hovered: true } },
    true, false);
check('explicit opening does not request hover lease',
    { ...base, explicitForThisOutput: true, _anchorHover: { hovered: true } },
    true, false);
check('popup body owns visit',
    { ...base, popupHovered: true }, false, true);
check('entry bridge may hold transfer',
    { ...base, entryBridgeHeld: true }, false, true);
check('no anchor item is safe',
    { ...base, anchorItem: null, _anchorHover: null }, false, false);
console.log('PASS: ' + assertions + ' NotificationCenter source/lease assertions');
