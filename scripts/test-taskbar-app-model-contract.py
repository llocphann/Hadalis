#!/usr/bin/env python3
"""Evaluate production app aggregation without a compositor or Qt binding."""
from pathlib import Path
import subprocess
root = Path(__file__).resolve().parents[1]
source = (root / 'services/TaskbarApps.qml').read_text()
def method(name):
    start = source.index('{', source.index('function ' + name + '('))
    depth = 1
    end = start + 1
    while depth:
        depth += (source[end] == '{') - (source[end] == '}')
        end += 1
    return source[start + 1:end - 1]
program = r'''
const assert = require('node:assert/strict');
const Config = {options:{dock:{pinnedApps:['FOO','missing'],ignoredAppRegexes:['ignored']}}};
const AppSearch = {lookupDesktopEntry:id => id.toLowerCase() === 'foo' ? {id} : null,
    resolveWindowIdentity:window => window.appId};
const CompositorService = {isNiri:true, sortedToplevels:[
    {appId:'foo',id:1},{appId:'BAR',id:2},{appId:'Foo',id:3},{appId:'ignored.app',id:4},{appId:'portal',id:5}]};
const ToplevelManager = {toplevels:{values:[{appId:'stale',id:99}]}};
const root = {_identityRulesRevision:0};
'''
for name in ['_stringArray','_compileRegexes','computeApps']:
    argument = 'value' if name == '_stringArray' else 'patterns' if name == '_compileRegexes' else ''
    program += f'root.{name} = function({argument}) {{\n{method(name)}\n}};\n'
program += r'''
let apps=root.computeApps();
assert.deepEqual(apps.map(app=>app.appId),['foo','SEPARATOR','bar']);
assert.equal(apps[0].pinned,true);
assert.deepEqual(apps[0].toplevels.map(window=>window.id),[1,3]);
assert.equal(apps[2].pinned,false);
assert.deepEqual(apps[2].toplevels.map(window=>window.id),[2]);
Config.options.dock.pinnedApps=['missing'];
assert.deepEqual(root.computeApps().map(app=>app.appId),['foo','bar']);
CompositorService.sortedToplevels=[];
assert.deepEqual(root.computeApps(),[],'Niri must never resurrect stale foreign handles');
CompositorService.isNiri=false;
assert.equal(root.computeApps()[0].appId,'stale');
CompositorService.sortedToplevels=[{appId:'valid',id:8}];
assert.equal(root.computeApps()[0].appId,'valid');
'''
subprocess.run(['node','-e',program],check=True)
print('PASS: taskbar aggregation preserves pins, case identity, filtering, ordering and authoritative Niri membership')
