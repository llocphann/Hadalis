#!/usr/bin/env python3
"""Exercise persisted navigation using the actual normalizer and actions."""
from pathlib import Path
import re, subprocess
root=Path(__file__).resolve().parents[1]
source=(root/"modules/settings/SettingsArrangement.qml").read_text()
program=(root/"modules/settings/SettingsNavigation.js").read_text()+r"""
const assert=require('node:assert/strict');
const defaults=[{label:'Home',pages:[0]},{label:'Abyss',pages:[2,3,4]},{label:'System',pages:[1]}];
let state=arrange(JSON.stringify({groups:[{label:'Abyss',pages:[2,2]},{label:'Abyss',pages:[3]},{label:'More',pages:[4]},{label:'More',pages:[]}]}),defaults,5,[]);
assert.equal(state.groups.filter(g=>g.label==='Abyss').length,1);
assert.equal(state.groups.filter(g=>g.label==='More').length,1);
assert.equal(state.groups.flatMap(g=>g.pages).length,5);
assert.equal(new Set(state.groups.flatMap(g=>g.pages)).size,5);
const SettingsPageRegistry={get categories(){return state.groups},get hiddenPages(){return state.hidden},defaultCategories:defaults};
const SettingsPageRegistryData={legacyHiddenIndexes:[]};
const Config={setNestedValue(key,value){assert.equal(key,'settingsUi.categories');state=arrange(value,defaults,5,[])}};
const root={layoutSchemaVersion:11};
"""
for match in re.finditer(r"    function (\w+)\(([^)]*)\)(?:: \w+)? \{",source):
    a=source.index("{",match.start());b=a+1;depth=1
    while depth:
        depth+=(source[b]=="{")-(source[b]=="}");b+=1
    header="function "+match[1]+"("+re.sub(r": \w+","",match[2])+") "
    program+="\nroot."+match[1]+"="+header+source[a:b]+";"
program+=r"""
let from=state.groups.findIndex(g=>g.pages.includes(2)),to=state.groups.findIndex(g=>g.label==='System');
assert(root.movePage(from,0,2,to,0));
assert(state.groups[to].pages.includes(2),'dragged tab persists outside original heading');
from=state.groups.findIndex(g=>g.label==='Abyss');
assert(root.removeCategory(from),'nonempty heading can be removed');
assert.equal(state.groups.filter(g=>g.label==='Abyss').length,0,'deleted heading is not injected again');
assert.equal(new Set(state.groups.flatMap(g=>g.pages)).size,5,'deleting a heading preserves every settings page');
for(let i=0;i<20;i++) {
    from=state.groups.findIndex(g=>g.pages.includes(2));to=(from+1)%state.groups.length;
    assert(root.movePage(from,state.groups[from].pages.indexOf(2),2,to,0));
    assert.equal(state.groups.flatMap(g=>g.pages).filter(p=>p===2).length,1,'repeated moves never duplicate pages');
}
assert(root.hidePage(to,0,2));assert(state.hidden.includes(2));
assert(root.restorePage(2));assert(!state.hidden.includes(2));
console.log('PASS: heading deletion, tab moves, deduplication, hidden-page restore and persisted navigation');
"""
subprocess.run(["node","-e",program],check=True,cwd=root)
