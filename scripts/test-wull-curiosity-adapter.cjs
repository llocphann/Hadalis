#!/usr/bin/env node
// Execute the production adapter, including guards, output ownership and
// actual selection of existing GlobalStates presentation APIs. No live UI.
const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const source=fs.readFileSync('modules/abyss/AbyssPerimeter.qml','utf8');
const state={};
const calls=[];
const window={outputName:'DP-1',companionPermission:true,companionOccluded:false,
    dockHovered:false,companionCuriosityDockRequested:false};
const scope=vm.createContext({window,GlobalStates:state,liquid:{popupsOpen:false},
    utility:{open:false},barHover:{hovered:false},revealHover:{hovered:false}});
for (const name of ['companionFeaturesIdle','openCompanionFeature','ownsCompanionFeature','closeCompanionFeature','releaseCompanionFeature']) {
    const start=source.indexOf('            function '+name+'(');
    assert.ok(start>=0);
    const opening=source.indexOf('{',start);let end=opening+1,depth=1;
    while(depth){depth+=(source[end]==='{')-(source[end]==='}');end++}
    const method=source.slice(start,end).replace(/\): (bool|void) \{/,') {');
    vm.runInContext(method,scope);window[name]=scope[name];
}
state.openSidebarLeft=(output)=>{state.sidebarLeftOpen=true;state.sidebarLeftTargetOutput=output;calls.push('openLeft')};
state.openSidebarRight=(output)=>{state.sidebarRightOpen=true;state.sidebarRightTargetOutput=output;calls.push('openRight')};
state.closeSidebarLeft=()=>{state.sidebarLeftOpen=false;calls.push('closeLeft')};
state.closeSidebarRight=()=>{state.sidebarRightOpen=false;calls.push('closeRight')};
window.closeGenericPopup=(kind)=>{if(state.abyssPopupKind===kind)state.abyssPopupKind='';calls.push(['closePopup',kind])};
function reset(){
    for (const key of ['sidebarLeftOpen','sidebarRightOpen','settingsOverlayOpen','overviewOpen','clipboardOpen',
        'dashboardOpen','controlPanelOpen','notificationCenterOpen','widgetEditMode','mediaControlsOpen'])state[key]=false;
    state.abyssPopupKind='';state.abyssPopupTargetOutput='';calls.length=0;
    state.sidebarLeftTransient=false;state.sidebarRightTransient=false;
}
function mature(){return {companionLease:null,acquireCompanion(owner){
    assert.equal(this.companionLease,null);this.companionLease=owner;calls.push('borrow');return true;
},releaseCompanion(owner){if(this.companionLease===owner){this.companionLease=null;calls.push('release')}}};}
let cases=0;
for (const kind of ['clock','resources','battery','weather','media','quickNotes','notificationCenter','utilities','leftPanel','rightPanel']) {
    reset();const feature={kind,edge:'right',along:312,key:kind};
    if(!['utilities','leftPanel','rightPanel'].includes(kind))feature.popup=mature();
    assert.equal(window.openCompanionFeature(feature),true,kind);
    assert.equal(window.ownsCompanionFeature(feature),true);
    if(feature.popup){assert.equal(state.abyssPopupKind,'');assert.equal(state.mediaControlsOpen,false);assert.equal(calls[0],'borrow');}
    window.closeCompanionFeature(feature);
    assert.equal(window.ownsCompanionFeature(feature),false,'owned presentation was not closed');cases++;
}
for (const kind of ['settings','dashboard','dock','run-command']) {
    reset();assert.equal(window.openCompanionFeature({kind,popup:mature()}),false);assert.equal(calls.length,0);cases++;
}
for (const blocker of ['sidebarLeftOpen','sidebarRightOpen','settingsOverlayOpen','overviewOpen','clipboardOpen',
    'dashboardOpen','controlPanelOpen','notificationCenterOpen','widgetEditMode','abyssPopupKind']) {
    reset();state[blocker]=blocker==='abyssPopupKind'?'weather':true;
    const before=JSON.stringify(state);
    assert.equal(window.openCompanionFeature({kind:'clock',popup:mature()}),false);
    assert.equal(JSON.stringify(state),before,'curiosity replaced existing human UI');cases++;
}
for (const [object,key] of [[scope.liquid,'popupsOpen'],[scope.utility,'open'],[scope.barHover,'hovered'],[scope.revealHover,'hovered'],[window,'dockHovered'],[window,'companionOccluded']]){
    reset();object[key]=true;assert.equal(window.openCompanionFeature({kind:'clock',popup:mature()}),false);object[key]=false;cases++;
}
reset();window.companionPermission=false;assert.equal(window.openCompanionFeature({kind:'clock',popup:mature()}),false);window.companionPermission=true;
for (const kind of ['utilities','leftPanel','rightPanel']) {
    reset();const feature={kind,edge:'top',along:200};assert.ok(window.openCompanionFeature(feature));
    const field=kind==='leftPanel'?'sidebarLeftTargetOutput':kind==='rightPanel'?'sidebarRightTargetOutput':'abyssPopupTargetOutput';
    state[field]='DP-2';const before=JSON.stringify(state),count=calls.length;
    window.closeCompanionFeature(feature);assert.equal(JSON.stringify(state),before);assert.equal(calls.length,count);cases++;
}
reset();const feature={kind:'clock',popup:mature()};assert.ok(window.openCompanionFeature(feature));
feature.popup.companionLease=null;const count=calls.length;window.closeCompanionFeature(feature);
assert.equal(calls.length,count,'departure closed a popup already handed to the user');
assert.equal(window.openCompanionFeature({kind:'clock'}),false,'missing mature popup used a duplicate fallback');
for (const kind of ['leftPanel','rightPanel']) {
    reset();const sidebar={kind};assert.ok(window.openCompanionFeature(sidebar));
    const open=kind==='leftPanel'?'sidebarLeftOpen':'sidebarRightOpen';
    const transient=kind==='leftPanel'?'sidebarLeftTransient':'sidebarRightTransient';
    window.releaseCompanionFeature(sidebar);
    assert.equal(state[open],true,'handoff immediately closed the hovered sidebar');
    assert.equal(state[transient],true,'handoff left a sticky companion sidebar');cases++;
    state[transient]=false;
    state[kind==='leftPanel'?'sidebarLeftTargetOutput':'sidebarRightTargetOutput']='DP-2';
    window.releaseCompanionFeature(sidebar);
    assert.equal(state[transient],false,'stale handoff mutated another output');cases++;
}
// Autonomous exploration cannot take keyboard input away from the current
// application. Pointer hand-off restores the host's existing focus policy.
const expression=source.match(/WlrLayershell\.keyboardFocus: ([\s\S]*?)\n\s*anchors \{/)[1].trim();
scope.WlrKeyboardFocus={None:0,OnDemand:1,Exclusive:2};
scope.field={ready:true};scope.PolkitService={active:false};scope.companionCuriosity={owned:false};
scope.talkCloud={editing:false};
window.presented=true;window.overviewDragging=false;window.editorOpen=false;
for (const id of ['popup','dialogBody','aux','clipboardBody','settings','dashboardBody','controls','leftPanel','rightPanel','notification'])
    scope[id]={presented:false,ready:true,open:false,contentItem:{item:{keyboardFocus:false}}};
const focus=()=>vm.runInContext(expression,scope);
scope.settings.presented=true;assert.equal(focus(),2);
scope.companionCuriosity.owned=true;assert.equal(focus(),0);
scope.companionCuriosity.owned=false;assert.equal(focus(),2);
scope.settings.presented=false;scope.leftPanel.presented=true;assert.equal(focus(),1);
scope.companionCuriosity.owned=true;assert.equal(focus(),0);
scope.companionCuriosity.owned=false;window.overviewDragging=true;assert.equal(focus(),0);
window.overviewDragging=false;scope.leftPanel.presented=false;
scope.talkCloud.editing=true;assert.equal(focus(),2,'the explicit shortcut gives Wull chat immediate keyboard focus');
scope.talkCloud.editing=false;assert.equal(focus(),0,'automatic Wull speech must never take keyboard focus');
console.log(`WULL_PRODUCTION_CURIOSITY_UI_OWNERSHIP_PASS cases=${cases}`);
