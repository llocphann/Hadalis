#!/usr/bin/env python3
"""Elastic Fill production wiring and user-visible vacancy borrowing contract."""
from pathlib import Path
import subprocess

ROOT=Path(__file__).resolve().parents[1]
geometry=(ROOT/"modules/abyss/looks/AbyssGeometry.js").read_text()
placement=(ROOT/"modules/abyss/looks/AbyssBodyPlacement.js").read_text()
elastic=(ROOT/"modules/abyss/looks/AbyssElasticFill.js").read_text()
motion=(ROOT/"modules/abyss/looks/AbyssPyramidMotion.js").read_text()
presentation=(ROOT/"modules/abyss/looks/AbyssPresentation.js").read_text()
host=(ROOT/"modules/abyss/AbyssBodyHost.qml").read_text()
controller=(ROOT/"modules/abyss/AbyssSurfaceController.qml").read_text()
perimeter=(ROOT/"modules/abyss/AbyssPerimeter.qml").read_text()
quick=(ROOT/"modules/screenCorners/QuickNotesPopup.qml").read_text()
center=(ROOT/"modules/notificationCenter/NotificationCenterPopup.qml").read_text()

for token in (
    'import "looks/AbyssElasticFill.js" as ElasticFill',
    "readonly property var baseBodyPlacements: BodyPlacement.arrange(",
    "readonly property var bodyPlacements: ElasticFill.resolve(",
    "function nextElasticFillInteractionOrder(): int",
):
    assert token in controller, token

for token in (
    'property string elasticFillGroup: ""',
    "property bool elasticFillHovered: false",
    "readonly property bool contentHovered: contentHover.hovered",
    "id: contentHover",
    "elasticFillGroup:root.elasticFillGroup",
    "elasticFillHovered:root.elasticFillHovered",
    "elasticFillOrder:root.elasticFillOrder",
    "property real elasticLimitProgress:",
    "Behavior on elasticLimitProgress",
):
    assert token in host, token

assert "elasticFillAnchor" not in host
assert "elasticFillAnchor" not in placement
assert "elasticFillAnchor" not in elastic
assert "elasticFillAnchor" not in perimeter
assert "anchor-before-follower" not in elastic

for token in (
    'elasticFillGroup: edge === "left"',
    "(leftReveal.edgeHovered || leftPanel.contentHovered)",
    "(rightReveal.edgeHovered || rightPanel.contentHovered)",
    "styledPopupHost.contentHovered",
    "Presentation.nearbyEdge(edge,along,span,",
    'elasticNearbyEdge === "left"',
    'elasticNearbyEdge === "right"',
):
    assert token in perimeter, token

assert 'liquidPresentationKind: "quickNotes"' in quick
assert 'liquidPresentationKind: "notificationCenter"' in center
assert "function _elasticPanelRect(member)" in elastic
assert "function _elasticDirections(owner,members)" in elastic
assert 'return ["bottom"]' in elastic and 'return ["top"]' in elastic
assert "placement.elasticLimits === true" in geometry
assert "elasticLimits:placement.elasticLimits === true" in motion

program=geometry+"\n"+placement+"\n"+elastic+"\n"+motion+r"""
const assert=require('node:assert/strict');
const W=1200,H=900,ins={left:16,right:16,top:16,bottom:16};

function close(a,b,t=.15){return Math.abs(a-b)<t}
function overlap(a,b,g=0){
    return a.x<b.x+b.width+g && a.x+a.width+g>b.x
        && a.y<b.y+b.height+g && a.y+a.height+g>b.y;
}
function request(id,edge,order,depth,along,span,group,hovered,hoverOrder,
        large=false) {
    const padding=14;
    const record=panel(W,H,ins,edge,along,span,depth,1,padding,[],large);
    return {
        id,open:true,order,priority:0,padding,
        allowInward:true,stackPolicy:"",stackProximity:24,
        minSpan:Math.min(record.span,220),
        minDepth:Math.min(record.targetDepth,120),
        elasticFillGroup:group,
        elasticFillHovered:hovered,
        elasticFillOrder:hoverOrder,
        record
    };
}
function outer(request,placement){
    return _elasticPanelRect({request,placement});
}

// User case A: Quick Notes exists first, Sidebar is the later hover.
// Do not reorder the base composition. Sidebar grows down through only the
// vacant vertical band created beside Quick Notes.
let notes=request("notes","bottom",1,320,500,420,
    "quickNotesSidebar",false,1,false);
let left=request("left","left",2,420,90,560,
    "quickNotesSidebar",true,2,true);
assert.deepEqual(_orderedRequests([notes,left]).map(x=>x.id),["left","notes"]);
let base=arrange([notes,left],W,H,ins);
let snapshot=JSON.stringify(base);
let filled=resolve([notes,left],base,24);
assert.equal(JSON.stringify(base),snapshot);
assert.equal(filled.left.elasticDirection,"bottom");
assert.equal(filled.notes.elasticFilled,undefined);
assert(filled.left.span>base.left.span);
assert(close(outer(left,filled.left).y+outer(left,filled.left).height,
    outer(notes,base.notes).y+outer(notes,base.notes).height));
assert(!overlap(filled.left.content,filled.notes.content,23.9));

// User case B: Sidebar exists first, Quick Notes is the later hover.
// Base order remains the normal activation order; Quick Notes grows upward.
left=request("left","left",1,420,90,560,
    "quickNotesSidebar",false,1,true);
notes=request("notes","bottom",2,320,500,420,
    "quickNotesSidebar",true,3,false);
assert.deepEqual(_orderedRequests([left,notes]).map(x=>x.id),["notes","left"]);
base=arrange([left,notes],W,H,ins);
filled=resolve([left,notes],base,24);
assert.equal(filled.notes.elasticDirection,"top");
assert.equal(filled.left.elasticFilled,undefined);
assert(filled.notes.depth>base.notes.depth);
assert(close(outer(notes,filled.notes).y,outer(left,base.left).y));
assert(!overlap(filled.left.content,filled.notes.content,23.9));

// The expanded placement must render exactly, and the relaxed limit must live
// through the return tail even after semantic Elastic Fill ownership is gone.
let rendered=placedPanel(W,H,ins,notes.record.edge,notes.record.along,
    notes.record.span,notes.record.targetDepth,1,notes.padding,[],false,
    filled.notes);
assert(close(rendered.content.y,filled.notes.content.y));
assert(close(rendered.content.height,filled.notes.content.height));
let tail=Object.assign({},filled.notes,{elasticFilled:false,elasticLimits:true});
let tailRecord=placedPanel(W,H,ins,notes.record.edge,notes.record.along,
    notes.record.span,notes.record.targetDepth,1,notes.padding,[],false,tail);
assert(close(tailRecord.content.y,filled.notes.content.y));
assert(close(tailRecord.content.height,filled.notes.content.height));

// Right-side mirror: Notifications/Activity and Sidebar Right use the same
// geometry-driven direction selection.
let center=request("center","bottom",1,500,280,420,
    "notificationsSidebar",false,1,true);
let right=request("right","right",2,420,90,560,
    "notificationsSidebar",true,4,true);
base=arrange([center,right],W,H,ins);
filled=resolve([center,right],base,24);
assert.equal(filled.right.elasticDirection,"bottom");
assert(!overlap(filled.right.content,filled.center.content,23.9));

// Latest hover wins only during a short overlap; hover loss is an exact no-op.
right.elasticFillHovered=true; right.elasticFillOrder=5;
center.elasticFillHovered=true; center.elasticFillOrder=6;
base=arrange([right,center],W,H,ins);
filled=resolve([right,center],base,24);
assert.equal(filled.center.elasticFilled,true);
assert.equal(filled.right.elasticFilled,undefined);
right.elasticFillHovered=false;
center.elasticFillHovered=false;
assert.equal(resolve([right,center],base,24),base);

console.log("Elastic Fill user scenarios: ok");
"""
subprocess.run(["node","-e",program],cwd=ROOT,check=True)

spatial=presentation+r"""
const assert=require('node:assert/strict');
assert.equal(nearbyEdge("bottom",-203,420,1920,1080),"left");
assert.equal(nearbyEdge("top",1703,420,1920,1080),"right");
assert.equal(nearbyEdge("bottom",750,420,1920,1080),"");
"""
subprocess.run(["node","-e",spatial],cwd=ROOT,check=True)
print("ok - Elastic Fill preserves base order and fills the hovered vacancy")
