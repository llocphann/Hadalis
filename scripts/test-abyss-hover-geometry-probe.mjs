#!/usr/bin/env node
// Read-only diagnostic parity: native input hit tests must distinguish the
// rectangular body, painted-connection strips and excluded source regions.
// No surface is mapped and no pointer handler is constructed.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const perimeter = readFileSync(resolve(root,
    'modules/abyss/AbyssPerimeter.qml'), 'utf8');
const geometry = readFileSync(resolve(root,
    'modules/abyss/looks/AbyssGeometry.js'), 'utf8');

function qmlFunction(src, name) {
    const pos = src.indexOf('function ' + name + '(');
    assert.ok(pos >= 0, 'missing diagnostic function ' + name);
    const brace = src.indexOf('{', pos);
    let nesting = 0;
    for (let i = brace; i < src.length; i++) {
        if (src[i] === '{') nesting++;
        else if (src[i] === '}' && --nesting === 0) {
            return src.slice(pos, i + 1).replace('): var {', ') {');
        }
    }
    throw new Error('unterminated diagnostic function ' + name);
}
const Geometry = new Function(geometry + '\nreturn {rectContains};')();
const window = { width: 1920, height: 1200 };
const nativeFn = new Function('Geometry', 'window',
    qmlFunction(perimeter, 'hoverProbeGeometry')
    + '\nreturn hoverProbeGeometry;')(Geometry, window);

const rect = (x, y, width, height) => ({ x, y, width, height });
const host = {
    edge: 'right', joinedEdge: 'bottom',
    connectionInsets: { left: 10, right: 10, top: 10, bottom: 10 },
    inputBounds: rect(1490, 616, 420, 560),
    rawPresentationRecord: { surface: rect(1490, 616, 420, 560) },
    record: { surface: rect(1490, 616, 430, 584) },
    // A narrow 1px strip outside the rectangular body: positive test.
    connectionRects: [rect(1890, 1199, 30, 1)],
    controller: { sourceInputRegions: [rect(1910, 1190, 10, 10)] },
};
let count = 0;
function expect(label, value, expected) {
    assert.equal(value, expected, label);
    count++;
}
const body = nativeFn(host, { x: 1800, y: 1100 });
expect('body within the input rectangle', body.pointHit.inInputBounds, true);
expect('body not in shoulder strip', body.pointHit.inShoulderStrip, false);
const strip = nativeFn(host, { x: 1899, y: 1199 });
expect('point outside input rectangle', strip.pointHit.inInputBounds, false);
expect('point within connector strip', strip.pointHit.inShoulderStrip, true);
expect('separate native source region not conflated', strip.pointHit.inSourceRegion, false);
const source = nativeFn(host, { x: 1919, y: 1199 });
expect('source overlap detectable', source.pointHit.inSourceRegion, true);
const gap = nativeFn(host, { x: 1880, y: 1180 });
expect('uncovered point is not connector or body', gap.pointHit.inInputBounds || gap.pointHit.inShoulderStrip, false);
expect('source does not include arbitrary workspace', gap.pointHit.inSourceRegion, false);
const absent = nativeFn(host, null);
expect('no pointer location after leave', absent.pointHit, null);
expect('diagnostic does not map a window', absent.outputWidth, 1920);
expect('absent host returns null', nativeFn(null, null), null);
assert.match(perimeter, /hoverGeometry:window\.hoverProbeGeometry\(host,/);
count++;
assert.match(perimeter, /popupMotion:liquid\.popupSlots\.filter/);
count++;
console.log('PASS: ' + count + ' scene-local hover geometry diagnostic assertions');
