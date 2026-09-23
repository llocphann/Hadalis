#!/usr/bin/env python3
"""Exercise the production Workflow identity and telemetry resolver functions."""

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


identity_path = "services/CodeWorkflowIdentity.qml"
runtime_path = "services/CodeWorkflowRuntime.qml"
identity_names = (
    "targetRef", "instanceRef", "graphNodeRef", "sourceRef", "isValid", "sanitize",
)
runtime_names = (
    "_kebabCase", "targetIdForPanel", "labelForPanel", "_identitySignature",
    "identityConflictFields", "computeIdentityCollisions", "discoveredDescriptors",
    "resolveRuntimeTelemetry",
)
payload = {
    "identity": {name: function_source(identity_path, name) for name in identity_names},
    "runtime": {name: function_source(runtime_path, name) for name in runtime_names},
}

media = (ROOT / "modules/bar/Media.qml").read_text(encoding="utf-8")
assert 'targetId: "bar/media"' in media and 'label: "Bar · Media"' in media

node_test = r"""
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const payload = JSON.parse(fs.readFileSync(0, 'utf8'));
function compile(source, context) {
    const js = source.replace(/:\s*(string|bool|var|int|real|double|void)(?=\s*[,){])/g, '');
    return vm.runInContext('(' + js + ')', context);
}
const identity = {};
const identityContext = vm.createContext({root: identity});
for (const [name, source] of Object.entries(payload.identity))
    identity[name] = compile(source, identityContext);
const runtime = {_identityDescriptors: () => []};
const runtimeContext = vm.createContext({root: runtime, CodeWorkflowIdentity: identity});
for (const [name, source] of Object.entries(payload.runtime))
    runtime[name] = compile(source, runtimeContext);

for (const [panel, targetId, label] of [
    ['iiBar', 'bar', 'Bar'],
    ['iiDashboard', 'dashboard', 'Dashboard'],
    ['iiSidebarLeft', 'sidebar/left', 'Sidebar Left'],
    ['wBar', 'waffle/bar', 'Waffle Bar'],
    ['iiFuturePanel', 'future-panel', 'Future Panel'],
]) {
    assert.equal(runtime.targetIdForPanel(panel), targetId);
    assert.equal(runtime.labelForPanel(panel), label);
}

const descriptor = (targetId, label, sourcePath = '') => ({
    targetId, label, family: 'ii', kind: 'surface', parentId: '', sourcePath,
});
runtime._identityDescriptors = () => [
    descriptor('settings', 'Settings', 'SettingsOverlay.qml'),
    descriptor('settings', 'Settings', 'SettingsFocus.qml'),
];
assert.equal(runtime.computeIdentityCollisions().length, 0,
    'alternate host source paths may share canonical identity');
runtime._identityDescriptors = () => [
    descriptor('future-panel', ''),
    descriptor('future-panel', 'Future Panel'),
    descriptor('future-panel', 'Wrong Future Panel'),
];
assert.equal(runtime.computeIdentityCollisions().length, 1,
    'a sparse first provider must not hide later label drift');
runtime._identityDescriptors = () => [
    descriptor('__proto__', 'First'), descriptor('__proto__', 'Second'),
];
assert.equal(runtime.computeIdentityCollisions().length, 1,
    'special object keys must not hide collisions');
runtime.declarations = {
    token: {descriptorSnapshot: () => descriptor('__proto__', 'Special')},
};
runtime.entries = {};
runtime.staleDescriptors = {};
assert.equal(runtime.discoveredDescriptors()[0].label, 'Special',
    'special object keys must remain discoverable');

const epoch = 'shell-generation-2';
const records = [
    {targetId:'bar',instanceId:'bar@HDMI-A-1',output:'HDMI-A-1',state:'resident',runtimeToken:epoch+':1'},
    {targetId:'bar',instanceId:'bar@DP-1',output:'DP-1',state:'resident',runtimeToken:epoch+':2'},
];
const snapshot = {
    epoch,
    descriptors: [
        descriptor('bar', 'Bar'),
        descriptor('bar/media', 'Bar · Media'),
        descriptor('dashboard', 'Dashboard'),
        descriptor('sidebar/left', 'Sidebar Left'),
        descriptor('waffle/bar', 'Waffle Bar'),
        descriptor('future-panel', 'Future Panel'),
    ],
    records,
    identityCollisions: [],
};
const resolve = (ref, evidence = snapshot, seenEpoch = epoch) =>
    runtime.resolveRuntimeTelemetry({ref, epoch:seenEpoch}, evidence);
for (const [targetId, label] of [
    ['bar','Bar'], ['bar/media','Bar · Media'], ['dashboard','Dashboard'],
    ['sidebar/left','Sidebar Left'], ['waffle/bar','Waffle Bar'],
    ['future-panel','Future Panel'],
]) {
    const result = resolve(identity.targetRef(targetId));
    assert.equal(result.status, 'resolved');
    assert.equal(result.descriptor.label, label);
}
const drift = resolve({kind:'target',targetId:'bar',label:'zzzBar',icon:'wrong'});
assert.equal(drift.descriptor.label, 'Bar');
assert.equal(Object.hasOwn(drift.ref, 'label'), false,
    'telemetry metadata cannot override Workflow presentation');
const orphan = resolve(identity.targetRef('unknown/new-component'));
assert.equal(orphan.status, 'orphan-target');
assert.equal(Object.hasOwn(orphan, 'descriptor'), false);
assert.equal(resolve(identity.instanceRef('bar','bar@HDMI-A-1')).instance.output,'HDMI-A-1');
assert.equal(resolve(identity.instanceRef('bar','bar@DP-1')).instance.output,'DP-1');
assert.equal(resolve(identity.instanceRef('bar','bar@missing')).status,'orphan-instance');
assert.equal(resolve(identity.targetRef('bar'),snapshot,'old-generation').status,'stale-generation');
assert.equal(resolve(identity.targetRef('bar'),snapshot,'').status,'missing-generation');
assert.equal(resolve(identity.graphNodeRef('bar','bar.loader')).status,'invalid-ref');
const collision = {...snapshot, identityCollisions:[{targetId:'bar'}]};
assert.equal(resolve(identity.targetRef('bar'),collision).status,'identity-collision');
const malformedCollisions = {...snapshot, identityCollisions:{}};
assert.equal(resolve(identity.targetRef('bar'),malformedCollisions).status,'resolved');
const duplicate = {...snapshot, descriptors:snapshot.descriptors.concat([descriptor('bar','Wrong')])};
assert.equal(resolve(identity.targetRef('bar'),duplicate).status,'identity-collision');
const staleInstance = {...snapshot,records:[{...records[0],state:'stale'}]};
assert.equal(resolve(identity.instanceRef('bar','bar@HDMI-A-1'),staleInstance).status,'orphan-instance');
console.log('ok - Workflow-owned telemetry identity, collisions, orphans, generations');
"""

subprocess.run(["node", "-e", node_test], input=json.dumps(payload),
               text=True, check=True)
