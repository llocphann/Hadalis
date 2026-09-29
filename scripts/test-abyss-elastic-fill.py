#!/usr/bin/env python3
"""Elastic Fill post-allocation geometry and Abyss integration contract."""
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
geometry = (ROOT / "modules/abyss/looks/AbyssGeometry.js").read_text()
placement = (ROOT / "modules/abyss/looks/AbyssBodyPlacement.js").read_text()
elastic = (ROOT / "modules/abyss/looks/AbyssElasticFill.js").read_text()
host = (ROOT / "modules/abyss/AbyssBodyHost.qml").read_text()
controller = (ROOT / "modules/abyss/AbyssSurfaceController.qml").read_text()
perimeter = (ROOT / "modules/abyss/AbyssPerimeter.qml").read_text()

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
    "elasticFillGroup:root.elasticFillGroup",
    "elasticFillHovered:root.elasticFillHovered",
    "elasticFillOrder:root.elasticFillOrder",
    "root.markElasticFillInteraction()",
    "elasticFilled: coordinatedPlacement?.elasticFilled === true",
):
    assert token in host, token

for token in (
    'elasticFillGroup: "quickNotesSidebar"',
    'elasticFillGroup: "notificationsSidebar"',
    'presentationKind === "quickNotes"',
    'presentationKind === "notificationCenter"',
    "hostedPopup?.popupHovered",
    "hostedPopup?.hoverTarget?.containsMouse",
):
    assert token in perimeter, token

assert "depthLimit=placement.elasticFilled === true ? 1 : undefined" in geometry

program = geometry + "\n" + placement + "\n" + elastic + r"""
const assert=require('node:assert/strict');
const edgeInsets={left:16,right:16,top:16,bottom:16};

function request(id,edge,order,depth,along,span,group,hovered,hoverOrder,
        large=false) {
    const padding=14;
    const record=panel(1200,900,edgeInsets,edge,along,span,depth,1,
        padding,[],large);
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
function allocated(requests) {
    return arrange(requests,1200,900,edgeInsets);
}
function overlap(a,b,gap=0) {
    return a.x<b.x+b.width+gap && a.x+a.width+gap>b.x
        && a.y<b.y+b.height+gap && a.y+a.height+gap>b.y;
}
function close(a,b) { return Math.abs(a-b)<0.1; }

// Screenshot case 1: Quick Notes is already present, then the Left Sidebar is
// hovered. The sidebar borrows the lower-left vacancy and grows downward.
let left=request("left","left",1,420,90,560,
    "quickNotesSidebar",true,2,true);
let notes=request("notes","bottom",2,320,500,420,
    "quickNotesSidebar",false,1,false);
let base=allocated([left,notes]);
let filled=resolve([left,notes],base,24);
assert.equal(filled.left.elasticDirection,"bottom");
assert(close(filled.left.content.y+filled.left.content.height,
    base.notes.content.y+base.notes.content.height));
assert.equal(filled.notes.elasticFilled,undefined);
assert(!overlap(filled.left.content,filled.notes.content,23.99));

// Screenshot case 2: reverse the hover order. Quick Notes consumes the upper
// vacancy, which requires more depth than an ordinary compact popup may use.
left.elasticFillHovered=false;
notes.elasticFillHovered=true;
notes.elasticFillOrder=3;
base=allocated([left,notes]);
filled=resolve([left,notes],base,24);
assert.equal(filled.notes.elasticDirection,"top");
assert(close(filled.notes.content.y,base.left.content.y));
assert(filled.notes.depth>base.notes.depth);
assert(!overlap(filled.left.content,filled.notes.content,23.99));

// Elastic placement geometry must honor the expanded content exactly, while an
// identical ordinary placement still obeys the normal compact depth cap.
const elasticRecord=placedPanel(1200,900,edgeInsets,"bottom",
    notes.record.along,notes.record.span,notes.record.targetDepth,1,14,[],
    false,filled.notes);
assert(close(elasticRecord.content.y,filled.notes.content.y));
assert(close(elasticRecord.content.height,filled.notes.content.height));
const ordinaryPlacement=Object.assign({},filled.notes,{elasticFilled:false});
const ordinaryRecord=placedPanel(1200,900,edgeInsets,"bottom",
    notes.record.along,notes.record.span,notes.record.targetDepth,1,14,[],
    false,ordinaryPlacement);
assert(ordinaryRecord.depth<filled.notes.depth);

// Right Sidebar + Notifications/Activity is the mirrored semantic pair.
let right=request("right","right",1,420,90,560,
    "notificationsSidebar",true,5,true);
let center=request("center","bottom",2,320,280,420,
    "notificationsSidebar",false,1,false);
base=allocated([right,center]);
filled=resolve([right,center],base,24);
assert.equal(filled.right.elasticDirection,"bottom");
assert(!overlap(filled.right.content,filled.center.content,23.99));

// No hover and a single open group member are strict no-ops.
right.elasticFillHovered=false;
base=allocated([right,center]);
assert.equal(resolve([right,center],base,24),base);
center.elasticFillHovered=true;
base=allocated([center]);
assert.equal(resolve([center],base,24),base);

// During a short hover-lease overlap, the most recently hovered member owns
// the vacancy rather than both bodies trying to fill it.
right.elasticFillHovered=true;
right.elasticFillOrder=6;
center.elasticFillHovered=true;
center.elasticFillOrder=7;
base=allocated([right,center]);
filled=resolve([right,center],base,24);
assert.equal(filled.center.elasticFilled,true);
assert.equal(filled.right.elasticFilled,undefined);

// Elastic Fill never mutates allocator truth. Hover loss can therefore animate
// back to the exact base placement without reconstructing saved geometry.
left.elasticFillHovered=true;
notes.elasticFillHovered=false;
base=allocated([left,notes]);
const snapshot=JSON.stringify(base);
resolve([left,notes],base,24);
assert.equal(JSON.stringify(base),snapshot);

console.log("Elastic Fill post-allocation contract: ok");
"""
subprocess.run(["node","-e",program],cwd=ROOT,check=True)
print("ok - Elastic Fill hover ownership, vacancy borrowing, restore and geometry")
