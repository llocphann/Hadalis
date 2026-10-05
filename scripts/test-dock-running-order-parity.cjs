#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");

const ROOT = path.resolve(__dirname, "..");
const DOCK = path.join(ROOT, "modules/dock/DockApps.qml");
const source = fs.readFileSync(DOCK, "utf8");

function requireBaseSourceContract() {
    for (const marker of [
        "function _doRebuildDockItems()",
        "const currentRunning = new Set(runningAppsMap.keys())",
        "const runningOrder = root._runningAppOrder.filter(appId => currentRunning.has(appId))",
        "root._runningAppOrder = runningOrder",
        "const pinnedOrder = new Map()"
    ]) {
        if (!source.includes(marker))
            throw new Error("DockApps running-order source contract lost " + JSON.stringify(marker));
    }
}

function requireOptimizedSourceContract() {
    for (const marker of [
        "const runningOrderSet = new Set(runningOrder)",
        "if (!runningOrderSet.has(lowerAppId))",
        "const runningOrderIndex = new Map()",
        "runningOrderIndex.get(a[0])",
        "runningOrderIndex.get(a.lowerAppId)"
    ]) {
        if (!source.includes(marker))
            throw new Error("DockApps optimized source contract lost " + JSON.stringify(marker));
    }
    if (source.includes("runningOrder.includes(lowerAppId)"))
        throw new Error("DockApps still performs linear running-order membership scans");
}

function baselineOrder(previous, currentKeys) {
    const current = new Set(currentKeys);
    const order = previous.filter(appId => current.has(appId));
    for (const appId of currentKeys) {
        if (!order.includes(appId))
            order.push(appId);
    }
    return order;
}

function optimizedOrder(previous, currentKeys) {
    const current = new Set(currentKeys);
    const order = previous.filter(appId => current.has(appId));
    const seen = new Set(order);
    for (const appId of currentKeys) {
        if (!seen.has(appId)) {
            seen.add(appId);
            order.push(appId);
        }
    }
    return order;
}

function firstIndexMap(order) {
    const result = new Map();
    for (let i = 0; i < order.length; ++i) {
        if (!result.has(order[i]))
            result.set(order[i], i);
    }
    return result;
}

function baselineOpenSort(entries, order) {
    return entries.slice().sort((a, b) => order.indexOf(a) - order.indexOf(b));
}

function optimizedOpenSort(entries, order) {
    const index = firstIndexMap(order);
    return entries.slice().sort((a, b) => index.get(a) - index.get(b));
}

function pinnedOrder(visiblePinnedApps) {
    const result = new Map();
    for (let i = 0; i < visiblePinnedApps.length; ++i)
        result.set(visiblePinnedApps[i].toLowerCase(), i);
    return result;
}

function baselineSeparateSort(entries, order, visiblePinnedApps) {
    const pins = pinnedOrder(visiblePinnedApps);
    return entries.slice().sort((a, b) => {
        const aPinned = pins.has(a);
        const bPinned = pins.has(b);
        if (aPinned && bPinned)
            return pins.get(a) - pins.get(b);
        if (aPinned !== bPinned)
            return aPinned ? -1 : 1;
        return order.indexOf(a) - order.indexOf(b);
    });
}

function optimizedSeparateSort(entries, order, visiblePinnedApps) {
    const pins = pinnedOrder(visiblePinnedApps);
    const index = firstIndexMap(order);
    return entries.slice().sort((a, b) => {
        const aPinned = pins.has(a);
        const bPinned = pins.has(b);
        if (aPinned && bPinned)
            return pins.get(a) - pins.get(b);
        if (aPinned !== bPinned)
            return aPinned ? -1 : 1;
        return index.get(a) - index.get(b);
    });
}

function assertArrayEqual(actual, expected, label) {
    if (actual.length !== expected.length
            || actual.some((value, index) => value !== expected[index])) {
        throw new Error(label + "\nexpected=" + JSON.stringify(expected)
            + "\nactual=" + JSON.stringify(actual));
    }
}

let state = 0x6d2b79f5;
function random() {
    state = (Math.imul(state ^ (state >>> 15), 1 | state)
        + 0x6d2b79f5) | 0;
    let t = Math.imul(state ^ (state >>> 7), 61 | state) ^ state;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
}
function pick(array) {
    return array[Math.floor(random() * array.length)];
}

const ids = [
    "alpha", "beta", "gamma", "delta", "spotify", "org.example.app",
    "__proto__", "constructor", "tostring", "", "null"
];

requireBaseSourceContract();

let cases = 0;
for (let round = 0; round < 50000; ++round) {
    const current = [];
    const currentCount = Math.floor(random() * 10);
    const pool = ids.slice();
    while (current.length < currentCount && pool.length > 0) {
        const index = Math.floor(random() * pool.length);
        current.push(pool.splice(index, 1)[0]);
    }

    const previous = [];
    const previousCount = Math.floor(random() * 14);
    for (let i = 0; i < previousCount; ++i)
        previous.push(pick(ids));

    const expectedOrder = baselineOrder(previous, current);
    const actualOrder = optimizedOrder(previous, current);
    assertArrayEqual(actualOrder, expectedOrder, "running-order parity failed");

    const subset = current.filter(() => random() >= 0.25);
    // Map iteration yields unique keys; shuffle to cover arbitrary current-map order.
    for (let i = subset.length - 1; i > 0; --i) {
        const j = Math.floor(random() * (i + 1));
        [subset[i], subset[j]] = [subset[j], subset[i]];
    }

    assertArrayEqual(
        optimizedOpenSort(subset, actualOrder),
        baselineOpenSort(subset, expectedOrder),
        "open-sort parity failed"
    );

    const visiblePins = [];
    const pinCount = Math.floor(random() * 10);
    for (let i = 0; i < pinCount; ++i)
        visiblePins.push(pick(ids).toUpperCase());

    assertArrayEqual(
        optimizedSeparateSort(subset, actualOrder, visiblePins),
        baselineSeparateSort(subset, expectedOrder, visiblePins),
        "separate-sort parity failed"
    );
    ++cases;
}

if (process.argv.includes("--production"))
    requireOptimizedSourceContract();

console.log("PASS: Dock running-order Set/first-index Map parity cases=" + cases);
