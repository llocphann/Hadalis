#!/usr/bin/env python3
"""Exercise session-bounded CPU history through the production QML helpers."""

import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def function_source(path: str, name: str) -> str:
    source = (ROOT / path).read_text(encoding="utf-8")
    start = source.index(f"function {name}(")
    opening = source.index("{", start)
    depth = 0
    for index in range(opening, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[start:index + 1]
    raise AssertionError(f"unclosed QML function: {name}")


payload = {
    "append": function_source("services/RuntimeDiagnostics.qml", "_appendHistory"),
    "samples": function_source(
        "modules/settings/widgets/BtopCoreGrid.qml", "samplesForCore"),
}

node_test = r"""
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const sources = JSON.parse(fs.readFileSync(0, 'utf8'));
function compile(source, context) {
    const js = source.replace(/:\s*(string|bool|var|int|real|double|void)(?=\s*[,){])/g, '');
    return vm.runInContext('(' + js + ')', context);
}

const runtime = {
    sampleHistory: [], historyLimit: 3,
    _historyPercent: () => null,
    _historyGpuPeak: () => null,
};
runtime._appendHistory = compile(sources.append, vm.createContext({root: runtime}));
const sample = (names, values, atMs) => ({
    atMs, system: {cpu: {percent: 20, coreNames: names, coresPercent: values}},
});
runtime._appendHistory(sample(['cpu0', 'cpu2'], [10, 80], 1));
runtime._appendHistory(sample(['cpu2', 'cpu0'], [70, 20], 2));
runtime._appendHistory(sample(['cpu2'], [60], 3));
assert.equal(runtime.sampleHistory.length, 3);
assert.deepEqual(Array.from(runtime.sampleHistory[1].coreNames), ['cpu2', 'cpu0']);

const grid = {coreNames: ['cpu0', 'cpu2'], history: runtime.sampleHistory};
grid.samplesForCore = compile(sources.samples, vm.createContext({root: grid}));
assert.deepEqual(Array.from(grid.samplesForCore(0)), [10, 20, null]);
assert.deepEqual(Array.from(grid.samplesForCore(1)), [80, 70, 60]);

runtime._appendHistory(sample(['cpu2', 'cpu0'], [null, 0], 4));
grid.history = runtime.sampleHistory;
assert.equal(runtime.sampleHistory.length, 3, 'the active-session ring stays bounded');
assert.deepEqual(Array.from(grid.samplesForCore(0)), [20, null, 0]);
assert.deepEqual(Array.from(grid.samplesForCore(1)), [70, 60, null]);
console.log('ok - logical CPU history follows IDs across reorder and hotplug');
"""

subprocess.run(["node", "-e", node_test], input=json.dumps(payload),
               text=True, check=True)
