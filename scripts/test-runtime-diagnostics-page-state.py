#!/usr/bin/env python3
"""Exercise the page-current gate used by cached Material Settings pages."""

from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
host = (ROOT / "modules/settings/SettingsPageHost.qml").read_text(encoding="utf-8")
for token in (
    'import "RuntimeDiagnosticsPageState.js" as DiagnosticsPageState',
    "DiagnosticsPageState.shouldLease(",
    "root.loadEnabled, root.visible,",
    "root.requestedIndex, root.currentIndex,",
    "onRequestedIndexChanged:",
    "onCurrentIndexChanged: root._syncDiagnosticsLease()",
    "onVisibleChanged: root._syncDiagnosticsLease()",
    "onLoadEnabledChanged:",
):
    if token not in host:
        raise SystemExit(f"FAIL: Settings host lease gate missing {token!r}")

script = r"""
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync(process.argv[1], 'utf8');
const shouldLease = vm.runInNewContext(source + '\nshouldLease');
const current = [true, true, 31, 31, 31];
assert.equal(shouldLease(...current), true);
assert.equal(shouldLease(true, true, 31, 30, 31), false,
    'pending page is not yet current');
assert.equal(shouldLease(true, true, 30, 31, 31), false,
    'leaving stops sampling while Diagnostics remains cached');
assert.equal(shouldLease(true, false, 31, 31, 31), false,
    'hidden Settings or search results stop sampling');
assert.equal(shouldLease(false, true, 31, 31, 31), false,
    'unloaded Settings stops sampling');
assert.equal(shouldLease(true, true, 31, 31, -1), false,
    'unregistered page cannot acquire');
console.log('ok - cached Settings page current lease gate');
"""
subprocess.run(
    ["node", "-e", script, str(ROOT / "modules/settings/RuntimeDiagnosticsPageState.js")],
    check=True,
)
