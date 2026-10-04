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
state.openSettingsSection=(page,section)=>{state.settingsOverlayOpen=true;state.settingsOverlayRequestedPage=page;calls.push(['settings',page,section])};
window.closeGenericPopup=(kind)=>{if(kind==='media')state.mediaControlsOpen=false;else if(state.abyssPopupKind===kind)state.abyssPopupKind='';calls.push(['closePopup',kind])};
function reset(){
    for (const key of ['sidebarLeftOpen','sidebarRightOpen','settingsOverlayOpen','overviewOpen','clipboardOpen',
        'dashboardOpen','controlPanelOpen','notificationCenterOpen','widgetEditMode','mediaControlsOpen'])state[key]=false;
    state.abyssPopupKind='';state.abyssPopupTargetOutput='';state.settingsOverlayRequestedPage=-1;state.settingsOverlayCurrentPage=-1;
    window.companionCuriosityDockRequested=false;calls.length=0;
}
let cases=0;
for (const kind of ['clock','resources','battery','weather','media','utilities','leftPanel','rightPanel','dock','settings']) {
    reset();const feature={kind,edge:'right',along:312,key:kind};
    assert.equal(window.openCompanionFeature(feature),true,kind);
    assert.equal(window.ownsCompanionFeature(feature),true);
    if(['clock','resources','battery','weather','media','utilities'].includes(kind)){
        assert.equal(state.abyssPopupTargetOutput,'DP-1');assert.equal(state.abyssPopupEdge,'right');assert.equal(state.abyssPopupAlong,312);
        assert.equal(state.mediaControlsOpen,kind==='media');assert.equal(state.abyssPopupKind,kind==='media'?'':kind);
    }
    if(kind==='settings')assert.deepEqual(calls[0],['settings',37,'Overview']);
    window.closeCompanionFeature(feature);
    assert.equal(window.ownsCompanionFeature(feature),false,'owned presentation was not closed');cases++;
}
for (const blocker of ['sidebarLeftOpen','sidebarRightOpen','settingsOverlayOpen','overviewOpen','clipboardOpen',
    'dashboardOpen','controlPanelOpen','notificationCenterOpen','widgetEditMode','mediaControlsOpen','abyssPopupKind']) {
    reset();state[blocker]=blocker==='abyssPopupKind'?'weather':true;
    const before=JSON.stringify(state);
    assert.equal(window.openCompanionFeature({kind:'clock'}),false);
    assert.equal(JSON.stringify(state),before,'curiosity replaced existing human UI');cases++;
}
for (const [object,key] of [[scope.liquid,'popupsOpen'],[scope.utility,'open'],[scope.barHover,'hovered'],[scope.revealHover,'hovered'],[window,'dockHovered'],[window,'companionOccluded']]){
    reset();object[key]=true;assert.equal(window.openCompanionFeature({kind:'clock'}),false);object[key]=false;cases++;
}
reset();window.companionPermission=false;assert.equal(window.openCompanionFeature({kind:'clock'}),false);window.companionPermission=true;
for (const kind of ['clock','media','leftPanel','rightPanel','settings']) {
    reset();const feature={kind,edge:'top',along:200};assert.ok(window.openCompanionFeature(feature));
    const field=kind==='settings'?'settingsOverlayTargetOutput':kind==='leftPanel'?'sidebarLeftTargetOutput':kind==='rightPanel'?'sidebarRightTargetOutput':'abyssPopupTargetOutput';
    state[field]='DP-2';const before=JSON.stringify(state),count=calls.length;
    window.closeCompanionFeature(feature);assert.equal(JSON.stringify(state),before);assert.equal(calls.length,count);cases++;
}
reset();const dock={kind:'dock'};assert.ok(window.openCompanionFeature(dock));window.releaseCompanionFeature(dock);
assert.equal(window.companionCuriosityDockRequested,false,'handoff retained a permanent Dock hold');
reset();assert.equal(window.openCompanionFeature({kind:'run-command'}),false);assert.equal(calls.length,0);
console.log(`WULL_PRODUCTION_CURIOSITY_UI_OWNERSHIP_PASS cases=${cases}`);
