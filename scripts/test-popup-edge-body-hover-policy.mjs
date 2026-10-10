#!/usr/bin/env node
// Source-expression regression for the revised Popup/Screen Edge hover policy.
// Native input masks remain unchanged. The owned popup surface includes
// ONLY the real input body and painted connector strips; source edge is the
// other owner. Read and execute the actual QML expressions.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const read = path => readFileSync(resolve(root, path), 'utf8');
const styled = read('modules/bar/StyledPopup.qml');
const perimeter = read('modules/abyss/AbyssPerimeter.qml');
const generic = read('modules/abyss/content/AbyssPopupContent.qml');
const notification = read('modules/notificationCenter/NotificationCenterPopup.qml');
const notes = read('modules/screenCorners/QuickNotesPopup.qml');
const geometry = read('modules/abyss/looks/AbyssGeometry.js');

function expression(src, marker, boundary) {
    const start = src.indexOf(marker);
    assert.ok(start >= 0, 'missing ' + marker);
    const end = src.indexOf(boundary, start + marker.length);
    assert.ok(end > start, 'missing boundary for ' + marker);
    return src.slice(start + marker.length, end).trim();
}
const sourceFn = new Function('root', 'return (' + expression(styled,
    'readonly property bool sourceEdgeHovered:',
    '\n    property bool barAutoHideHoldEnabled:') + ');');
const requestFn = new Function('root', 'return (' + expression(styled,
    'readonly property bool humanVisibleRequest:',
    '\n    onHumanVisibleRequestChanged:') + ');');
const Geometry = new Function(geometry + '\nreturn { rectContains, popupConnectedHover };')();
const hostedFn = new Function('styledPopupHost', 'popupContentHover', 'Geometry',
    'return (' + expression(perimeter,
        'readonly property bool connectedPopupHovered:',
        '\n                    onConnectedPopupHoveredChanged:') + ');');
const genericBodyFn = new Function('root', 'popupHover', 'Geometry',
    'return (' + expression(generic,
        'readonly property bool connectedPopupHovered:',
        '\n    readonly property bool editorFocusHeld:') + ');');
const noteFn = new Function('root', 'return (' + expression(notes,
    'alternativeVisibleCondition:',
    '\n    // Pre-arm click-to-focus') + ');');

let count=0;
function check(label, actual, expected) {
    assert.equal(actual, expected, label);
    count++;
}
const host = {
    acceptsInput: true,
    inputBounds: { x: 1490, y: 616, width: 420, height: 560 },
    connectionRects: [{ x: 1890, y: 1180, width: 20, height: 20 }],
    controller: { sourceInputRegions: [{ x: 1910, y: 1190, width: 10, height: 10 }] },
};
const pointer = (x,y,hovered=true) => ({hovered,point:{scenePosition:{x,y}}});
check('body content owns hover', hostedFn(host,pointer(1780,1100),Geometry), true);
check('popup border padding stays inside body',hostedFn(host,pointer(1491,617),Geometry),true);
check('actual connected shoulder strip retains hosted Popup',
    hostedFn(host,pointer(1903,1195),Geometry),true);
check('nearby empty workspace does not own Popup',
    hostedFn(host,pointer(1880,1195),Geometry),false);
// All four physical Screen Edges must retain ONLY their actual narrow
// connector strips. Their rectangular bounding boxes/empty corners must
// never create an output-wide invisible hover catcher.
for (const [edge,body,strip,p,miss] of [
    ['top',{x:600,y:20,width:300,height:200},{x:700,y:0,width:25,height:20},{x:710,y:8},{x:750,y:8}],
    ['bottom',{x:600,y:980,width:300,height:200},{x:700,y:1180,width:25,height:20},{x:710,y:1195},{x:750,y:1195}],
    ['left',{x:20,y:400,width:300,height:300},{x:0,y:500,width:20,height:25},{x:10,y:510},{x:10,y:550}],
    ['right',{x:1600,y:400,width:300,height:300},{x:1900,y:500,width:20,height:25},{x:1910,y:510},{x:1910,y:550}]
]) {
    check(edge+' painted strip belongs to the popup',
        Geometry.popupConnectedHover(body,[strip],[],p.x,p.y),true);
    check(edge+' adjacent unused Screen Edge does not belong to popup',
        Geometry.popupConnectedHover(body,[strip],[],miss.x,miss.y),false);
}
check('source-occupied portion of connector is excluded',
    Geometry.popupConnectedHover(host.inputBounds,host.connectionRects,
        [{x:1900,y:1190,width:10,height:10}],1903,1195),false);
check('unknown cursor coordinates cannot keep popup alive',
    Geometry.popupConnectedHover(host.inputBounds,host.connectionRects,[],NaN,1195),false);
check('outside popup cannot own hover',hostedFn(host,pointer(1400,800),Geometry),false);
check('source region does not become popup hover',hostedFn(host,pointer(1919,1199),Geometry),false);
check('no hovered point cannot own popup',hostedFn(host,pointer(1780,1100,false),Geometry),false);
const genericParticipant = { ...host };
check('generic Popup body owns hover',genericBodyFn({participant:genericParticipant},
    pointer(1780,1100),Geometry),true);
check('generic actual connected strip owns popup surface',genericBodyFn({participant:genericParticipant},
    pointer(1903,1195),Geometry),true);
check('generic non-painted gap cannot keep Popup open',genericBodyFn({participant:genericParticipant},
    pointer(1880,1195),Geometry),false);
check('generic dismissed/unready body does NOT own hover',genericBodyFn({
    participant:{...genericParticipant,acceptsInput:false}},pointer(1780,1100),Geometry),false);
check('disabled/unpresented body cannot own hover',
    hostedFn({...host,acceptsInput:false},pointer(1780,1100),Geometry),false);
const source = (module,handler) => ({moduleHoverActive:module,_anchorHover:{hovered:handler}});
check('source edge owns visit',sourceFn(source(true,false)),true);
check('source QML HoverHandler owns visit',sourceFn(source(false,true)),true);
check('unrelated areas do not own visit',sourceFn(source(false,false)),false);
const request = (edge,body,other=false) => ({
    hoverActivates:true,sourceEdgeHovered:edge,popupHovered:body,
    alternativeVisibleCondition:other
});
check('edge opens and holds popup',requestFn(request(true,false)),true);
check('body opens and holds popup',requestFn(request(false,true)),true);
check('either owner holds during reverse transit',requestFn(request(true,true)),true);
check('no source or connected Popup cannot hold',requestFn(request(false,false)),false);
check('explicit opens remain independent',requestFn(request(false,false,true)),true);
check('non-hover caller does not open on pointer',
    requestFn({...request(true,true),hoverActivates:false}),false);
check('Quick Notes pin survives hover exit',
    noteFn({editorFocused:false,todoDialogOpen:false,popupPinned:true}),true);
check('Quick Notes text editor focus survives hover exit',
    noteFn({editorFocused:true,todoDialogOpen:false,popupPinned:false}),true);
check('Quick Notes no pin/keyboard and no hover releases',
    noteFn({editorFocused:false,todoDialogOpen:false,popupPinned:false}),false);
assert.doesNotMatch(notification,/entryBridgeHeld|entryBridgeTimer/);count++;
assert.doesNotMatch(notes,/entryBridgeHeld|entryBridgeTimer/);count++;
assert.match(notification,/root\._anchorHovered[\s\S]*?\|\| root\.popupHovered[\s\S]*?dragActive/);count++;
assert.match(notification,/exitGraceTimer\.restart\(\)/);count++;
assert.match(styled,/hoverTransferGraceMs: 90/);count++;
assert.match(perimeter,/onConnectedPopupHoveredChanged:/);count++;
assert.match(generic,/root\.triggerHovered \|\| root\.connectedPopupHovered \|\| root\.editorFocusHeld/);count++;
assert.match(generic,/!root\.triggerHovered && !root\.connectedPopupHovered && !root\.editorFocusHeld/);count++;
console.log('PASS: '+count+' actual QML source-edge/popup hover-policy assertions');
