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
const merged=arrange(JSON.stringify({groups:[{label:' System ',pages:[1]},{label:'system',pages:[2]},{label:'Appearance',pages:[3]},{label:'Appearance',pages:[4]}]}),defaults,5,[]);
assert.deepEqual(merged.groups.find(g=>g.label==='System').pages,[1,2]);
assert.deepEqual(merged.groups.find(g=>g.label==='Appearance').pages,[3,4]);
assert.equal(merged.groups.length,3,'every duplicate heading is merged, with the first position and label preserved');
const lower=arrange(JSON.stringify([{label:' system ',pages:[1]}]),[{label:'Home',pages:[0]},{label:'System',pages:[1,2,3,4]}],5,[]);
assert.equal(lower.groups.filter(g=>g.label.toLowerCase()==='system').length,1,'restoring unassigned tabs cannot recreate a duplicate heading');
assert.deepEqual(lower.groups.find(g=>g.label==='system').pages,[1,2,3,4]);
assert.equal(state.groups.filter(g=>g.label==='Abyss').length,1);
assert.equal(state.groups.filter(g=>g.label==='More').length,1);
assert.equal(state.groups.flatMap(g=>g.pages).length,5);
assert.equal(new Set(state.groups.flatMap(g=>g.pages)).size,5);
const SettingsPageRegistry={get categories(){return state.groups},get hiddenPages(){return state.hidden},defaultCategories:defaults,navigationPageIndexes:()=>state.groups.flatMap(g=>g.pages)};
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
let order=()=>SettingsPageRegistry.navigationPageIndexes(false);
while(order().indexOf(2)<order().length-1)assert(root.movePageFlat(2,1));
assert(state.groups.find(g=>g.label==='System').pages.includes(2),'adjacent moves persist across category boundaries');
assert(!root.movePageFlat(2,1),'moving beyond the final page must be a no-op');
for(let i=0;i<20;i++) {
 const index=order().indexOf(2),direction=index===0 ? 1 : index===order().length-1 ? -1 : i%2 ? 1 : -1;
 assert(root.movePageFlat(2,direction));
 assert.equal(order().filter(p=>p===2).length,1,'repeated moves never duplicate pages');
 assert.equal(new Set(order()).size,5,'moving preserves every page');
}
assert(root.hidePageById(2));assert(state.hidden.includes(2));assert(!order().includes(2));
assert(!root.hidePageById(2),'a hidden page cannot be hidden twice');
assert(root.restorePage(2));assert(!state.hidden.includes(2));assert.equal(order().filter(p=>p===2).length,1);
assert(!root.restorePage(2),'a visible page cannot be restored twice');
root.reset();assert.equal(order().length,5);assert.equal(state.hidden.length,0);
console.log('PASS: adjacent tab moves, boundary no-ops, deduplication, hidden-page restore and persisted navigation');
"""
subprocess.run(["node","-e",program],check=True,cwd=root)
