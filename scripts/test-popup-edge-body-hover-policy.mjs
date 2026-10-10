#!/usr/bin/env node
// Source-expression regression for the revised Popup/Screen Edge hover policy.
// Native input masks remain unchanged; only the owning anchor or popup body
// may renew the visit. Read and execute the actual QML expressions.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const read = path => readFileSync(resolve(root, path), 'utf8');
const styled = read('modules/bar/StyledPopup.qml');
const perimeter = read('modules/abyss/AbyssPerimeter.qml');
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
const Geometry = new Function(geometry + '\nreturn { rectContains };')();
const hostedFn = new Function('styledPopupHost', 'popupContentHover', 'Geometry',
    'return (' + expression(perimeter,
        'readonly property bool realPopupBodyHovered:',
        '\n                    onRealPopupBodyHoveredChanged:') + ');');
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
    controller: { sourceInputRegions: [{ x: 1910, y: 1190, width: 10, height: 10 }] },
};
const pointer = (x,y,hovered=true) => ({hovered,point:{scenePosition:{x,y}}});
check('body content owns hover', hostedFn(host,pointer(1780,1100),Geometry), true);
check('popup border padding stays inside body',hostedFn(host,pointer(1491,617),Geometry),true);
check('shoulder strip does not independently own hover',
    hostedFn(host,pointer(1903,1195),Geometry),false);
check('outside popup cannot own hover',hostedFn(host,pointer(1400,800),Geometry),false);
check('source region does not become popup hover',hostedFn(host,pointer(1919,1199),Geometry),false);
check('no hovered point cannot own popup',hostedFn(host,pointer(1780,1100,false),Geometry),false);
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
check('bridge-only does not hold',requestFn(request(false,false)),false);
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
assert.match(perimeter,/onRealPopupBodyHoveredChanged:/);count++;
console.log('PASS: '+count+' actual QML source-edge/popup hover-policy assertions');
