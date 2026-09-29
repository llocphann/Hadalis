#!/usr/bin/env python3
"""Production-semantic and geometry regression for Abyss vacancy borrowing."""
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(source: str, token: str, message: str) -> None:
    if token not in source:
        raise SystemExit(f"FAIL: {message} ({token})")


def section(source: str, start: str, end: str) -> str:
    first = source.find(start)
    last = source.find(end, first + len(start))
    if first < 0 or last < 0:
        raise SystemExit(f"FAIL: production wiring section missing: {start}")
    return source[first:last]


perimeter = read("modules/abyss/AbyssPerimeter.qml")
controller = read("modules/abyss/AbyssSurfaceController.qml")
host = read("modules/abyss/AbyssBodyHost.qml")
participant = read("modules/abyss/AbyssParticipant.qml")
layout = read("services/ShellLayoutController.qml")
corners = read("modules/abyss/AbyssCorners.qml")
left_content = read("modules/sidebarLeft/SidebarLeftContent.qml")
right_content = read("modules/sidebarRight/CompactSidebarRightContent.qml")
borrowing = read("modules/abyss/looks/AbyssVacancyBorrowing.js")
geometry = read("modules/abyss/looks/AbyssGeometry.js")
placement = read("modules/abyss/looks/AbyssBodyPlacement.js")

# Production semantic identity must survive both tab changes and physical swaps.
for token in (
    'id: "featureSidebar"',
    'id: "systemSidebar"',
    "function sidebarAssignments(): var",
    'updates["sidebar.shellLayout." + targetRole + ".slot"] = slot',
):
    require(layout, token, "ShellLayoutController logical sidebar identity/swap contract missing")

left_panel = section(perimeter, "id: leftPanel", "id: rightPanel")
right_panel = section(perimeter, "id: rightPanel", "AbyssGenericPopupPresenter")
styled_hosts = section(perimeter, "id: styledPopupHosts", "property bool dockHovered")

for token in (
    'vacancyRole: "featureSidebar"',
    'ShellLayoutController.currentState("featureSidebar",window.outputName)',
):
    require(left_panel, token, "feature sidebar production vacancy wiring missing")
for token in (
    'vacancyRole: "systemSidebar"',
    'ShellLayoutController.currentState("systemSidebar",window.outputName)',
):
    require(right_panel, token, "system sidebar production vacancy wiring missing")
for token in (
    'presentationKind === "quickNotes"',
    '? "quickNotes"',
    'presentationKind === "notificationCenter"',
    '? "notificationCenter" : ""',
):
    require(styled_hosts, token, "rehosted popup semantic/body-hover wiring missing")

# Borrowing hover must be owned by the final rendered BodyHost body. Production
# sections must not override it with source-anchor/reveal proxy state.
for production_section, label in (
    (left_panel, "feature sidebar"),
    (right_panel, "system sidebar"),
    (styled_hosts, "styled popup"),
):
    if "vacancyHovered:" in production_section:
        raise SystemExit(f"FAIL: {label} overrides final-body vacancy hover")

# Tabs/sections remain content state below the stable logical hosts.
for token in ("property string selectedTabId:", "id: swipeView", "music", "translator", "tools"):
    require(left_content, token, "feature sidebar tab contract missing")
for token in ("property int activeSection:", "calendar", "notepad", "controls"):
    require(right_content, token, "system sidebar section contract missing")
for token in (
    'kind:"quickNotes"',
    'kind:"notificationCenter"',
):
    require(corners, token, "corner popup semantic kind missing")

# The allocator request remains free of temporary semantics.
for token in (
    'property string vacancyRole: ""',
    "property bool vacancyHovered: root.vacancyRole.length > 0",
    "id: vacancyBodyHover",
    "parent: contentFrame",
    "enabled: root.vacancyRole.length > 0",
    "property int vacancyHoverOrder: 0",
    "vacancyRole: root.vacancyRole",
    "vacancyHovered: root.vacancyHovered",
    "vacancyHoverOrder: root.vacancyHoverOrder",
):
    require(host + participant, token, "host/participant presentation metadata missing")
if "vacancyRole:root.vacancyRole" in host.split("placementRequest:", 1)[1][:500]:
    raise SystemExit("FAIL: vacancy metadata leaked into the base allocator request")

for token in (
    'import "looks/AbyssVacancyBorrowing.js" as VacancyBorrowing',
    "readonly property var baseBodyPlacements: BodyPlacement.arrange(",
    "readonly property var bodyPlacements: VacancyBorrowing.resolve(",
    "placementRequests,vacancyParticipants,baseBodyPlacements",
):
    require(controller, token, "controller post-allocation resolver contract missing")

for token in (
    'featureSidebar: "quickNotes"',
    'systemSidebar: "notificationCenter"',
    '["featureSidebar","systemSidebar"]',
    "Automatic ownership prefers the logical sidebar",
    "hoveredTransactions",
    "One output owns one temporary borrower at a time",
):
    require(borrowing, token, "semantic pairing/arbitration contract missing")

# The old physical-edge grouping failure must not return.
for retired in (
    "elasticFillGroup",
    "elasticNearbyEdge",
    "quickNotesSidebar",
    "notificationsSidebar",
):
    if retired in perimeter or retired in controller or retired in host:
        raise SystemExit(f"FAIL: retired physical Elastic Fill wiring returned ({retired})")

program = geometry + "\n" + placement + "\n" + borrowing + r"""
const assert=require("node:assert/strict");
const W=1200,H=900,IN={left:16,right:16,top:16,bottom:16},GAP=24;

function member(id,role,edge,order,placement) {
    const padding=14;
    return {
        request:{id,open:true,order,priority:0,padding,minSpan:120,minDepth:80,
            allowInward:true,stackPolicy:"",stackProximity:24,
            record:{edge,along:placement.along,span:placement.span,
                targetDepth:placement.depth,depth:placement.depth}},
        meta:{id,role,hovered:false,hoverOrder:0},
        placement
    };
}
function approx(a,b,msg) {
    assert(Math.abs(a-b)<1e-6,msg+" "+a+" != "+b);
}
function sameRect(a,b,msg) {
    approx(a.x,b.x,msg+".x"); approx(a.y,b.y,msg+".y");
    approx(a.width,b.width,msg+".width"); approx(a.height,b.height,msg+".height");
}
function collide(a,b,gap=GAP) {
    return a.x < b.x+b.width+gap && a.x+a.width+gap > b.x
        && a.y < b.y+b.height+gap && a.y+a.height+gap > b.y;
}
function resolveMembers(members,width=W,height=H) {
    const requests=members.map(m=>m.request);
    const metadata=members.map(m=>m.meta);
    const placements=Object.fromEntries(members.map(m=>[m.request.id,m.placement]));
    return {base:placements,resolved:resolve(requests,metadata,placements,width,height,IN,GAP)};
}

const feature=member("leftPanel","featureSidebar","left",1,{
    visible:true,evicted:false,along:136,inward:440,span:608,depth:458,shrunk:false,
    content:{x:470,y:150,width:430,height:580}
});
const notes=member("styledPopup0","quickNotes","bottom",2,{
    visible:true,evicted:false,along:30,inward:0,span:418,depth:298,shrunk:false,
    content:{x:44,y:600,width:390,height:270}
});

// Automatic mode: coexistence plus real vacancy is sufficient. The logical
// sidebar is the stable default owner; no pointer hover is required.
let run=resolveMembers([feature,notes]);
assert(run.resolved.leftPanel.vacancyBorrowed);
assert.equal(run.resolved.leftPanel.vacancyDirection,"bottom");
assert(run.resolved.leftPanel.content.height>feature.placement.content.height);
assert(!run.resolved.styledPopup0.vacancyBorrowed);
assert(!collide(run.resolved.leftPanel.content,notes.placement.content));

// Hover remains an explicit temporary override when the hovered member has
// real geometry available.
notes.meta.hovered=true; notes.meta.hoverOrder=11;
run=resolveMembers([feature,notes]);
assert(run.resolved.styledPopup0.vacancyBorrowed);
assert.equal(run.resolved.styledPopup0.vacancyDirection,"top");
assert(!run.resolved.leftPanel.vacancyBorrowed);
assert(!collide(run.resolved.styledPopup0.content,feature.placement.content));

let record=placedPanel(W,H,IN,notes.request.record.edge,
    notes.request.record.along,notes.request.record.span,notes.request.record.targetDepth,
    1,notes.request.padding,[],true,run.resolved.styledPopup0);
sameRect(record.content,run.resolved.styledPopup0.content,"resolved record/content");

// Overlapping hover leases still deterministically select only the newest.
feature.meta.hovered=true; feature.meta.hoverOrder=12;
notes.meta.hovered=true; notes.meta.hoverOrder=13;
run=resolveMembers([feature,notes]);
assert(run.resolved.styledPopup0.vacancyBorrowed);
assert(!run.resolved.leftPanel.vacancyBorrowed);

// Hover loss returns to automatic ownership rather than collapsing to base.
feature.meta.hovered=false; notes.meta.hovered=false;
run=resolveMembers([feature,notes]);
assert(run.resolved.leftPanel.vacancyBorrowed);
assert(!run.resolved.styledPopup0.vacancyBorrowed);

// Losing the semantic peer restores exact allocator truth and object identity.
notes.request.open=false;
run=resolveMembers([feature,notes]);
assert.strictEqual(run.resolved,run.base);
assert.deepEqual(run.resolved.leftPanel,feature.placement);
assert.deepEqual(run.resolved.styledPopup0,notes.placement);
notes.request.open=true;

// Physical sidebar swap changes geometry only; semantic auto-pairing survives.
feature.request.record.edge="right";
feature.placement={
    visible:true,evicted:false,along:136,inward:0,span:608,depth:458,shrunk:false,
    content:{x:740,y:150,width:430,height:580}
};
run=resolveMembers([feature,notes]);
assert(run.resolved.leftPanel.vacancyBorrowed,
    "swapped feature sidebar must keep automatic Quick Notes pairing");

// Custom popup placement keeps the same semantic relationship.
notes.request.record.edge="top";
notes.placement={
    visible:true,evicted:false,along:30,inward:0,span:418,depth:298,shrunk:false,
    content:{x:44,y:30,width:390,height:270}
};
feature.request.record.edge="left";
feature.placement={
    visible:true,evicted:false,along:136,inward:440,span:608,depth:458,shrunk:false,
    content:{x:470,y:150,width:430,height:580}
};
run=resolveMembers([feature,notes]);
assert(run.resolved.leftPanel.vacancyBorrowed,
    "custom Quick Notes position lost automatic semantic pairing");

// System sidebar follows the same automatic relationship with Notification Center.
const system=member("rightPanel","systemSidebar","right",3,{
    visible:true,evicted:false,along:136,inward:440,span:608,depth:458,shrunk:false,
    content:{x:300,y:150,width:430,height:580}
});
const center=member("styledPopup1","notificationCenter","bottom",4,{
    visible:true,evicted:false,along:752,inward:0,span:418,depth:298,shrunk:false,
    content:{x:766,y:600,width:390,height:270}
});
run=resolveMembers([system,center]);
assert(run.resolved.rightPanel.vacancyBorrowed);
assert(!run.resolved.styledPopup1.vacancyBorrowed);

// Two independent pairs still produce only one automatic borrower. The newer
// active pair wins globally, while hover can explicitly override that choice.
const arbFeature=member("leftPanel","featureSidebar","left",31,{
    visible:true,evicted:false,along:86,inward:270,span:328,depth:228,shrunk:false,
    content:{x:300,y:100,width:200,height:300}
});
const arbNotes=member("styledPopup0","quickNotes","bottom",32,{
    visible:true,evicted:false,along:30,inward:0,span:248,depth:228,shrunk:false,
    content:{x:44,y:670,width:220,height:200}
});
const arbSystem=member("rightPanel","systemSidebar","right",33,{
    visible:true,evicted:false,along:86,inward:270,span:328,depth:228,shrunk:false,
    content:{x:700,y:100,width:200,height:300}
});
const arbCenter=member("styledPopup1","notificationCenter","bottom",34,{
    visible:true,evicted:false,along:922,inward:0,span:248,depth:228,shrunk:false,
    content:{x:936,y:670,width:220,height:200}
});
run=resolveMembers([arbFeature,arbNotes,arbSystem,arbCenter]);
assert.equal(Object.values(run.resolved).filter(p=>p.vacancyBorrowed).length,1);
assert(run.resolved.rightPanel.vacancyBorrowed,
    "newer semantic pair must own automatic borrowing");

arbFeature.meta.hovered=true;arbFeature.meta.hoverOrder=100;
run=resolveMembers([arbFeature,arbNotes,arbSystem,arbCenter]);
assert.equal(Object.values(run.resolved).filter(p=>p.vacancyBorrowed).length,1);
assert(run.resolved.leftPanel.vacancyBorrowed,
    "eligible body hover must override automatic pair ownership");
arbFeature.meta.hovered=false;

// An unrelated visible body can make the preferred sidebar ineligible. The
// semantic popup may then become the automatic fallback; blocker identity is
// never treated as a pairing signal.
notes.request.record.edge="bottom";
notes.placement={
    visible:true,evicted:false,along:30,inward:0,span:418,depth:298,shrunk:false,
    content:{x:44,y:600,width:390,height:270}
};
feature.request.record.edge="left";
feature.placement={
    visible:true,evicted:false,along:136,inward:440,span:608,depth:458,shrunk:false,
    content:{x:470,y:150,width:430,height:580}
};
const blocker=member("unrelated","none","bottom",40,{
    visible:true,evicted:false,along:470,inward:0,span:430,depth:146,shrunk:false,
    content:{x:484,y:754,width:402,height:118}
});
run=resolveMembers([feature,notes,blocker]);
assert(!run.resolved.leftPanel.vacancyBorrowed,
    "blocked preferred sidebar must not expand through unrelated content");
assert(run.resolved.styledPopup0.vacancyBorrowed,
    "eligible semantic peer should be the automatic fallback");
assert(!run.resolved.unrelated.vacancyBorrowed);

// No directional vacancy remains a strict object-identity no-op.
const noGapPeer=member("styledPopup0","quickNotes","left",51,{
    visible:true,evicted:false,along:136,inward:440,span:608,depth:458,shrunk:false,
    content:{x:470,y:150,width:430,height:580}
});
run=resolveMembers([feature,noGapPeer]);
assert.strictEqual(run.resolved,run.base);

// Small/fractional outputs remain finite and inside hard bounds.
const smallFeature=member("leftPanel","featureSidebar","left",60,{
    visible:true,evicted:false,along:80.25,inward:250.5,span:300.25,depth:280.25,shrunk:false,
    content:{x:280.5,y:94.25,width:252.25,height:272.25}
});
const smallNotes=member("styledPopup0","quickNotes","bottom",61,{
    visible:true,evicted:false,along:30.25,inward:0,span:238.25,depth:158.25,shrunk:false,
    content:{x:44.25,y:305.5,width:210.25,height:130.25}
});
run=resolveMembers([smallFeature,smallNotes],640.5,480.25);
assert.equal(Object.values(run.resolved).filter(p=>p.vacancyBorrowed).length,1);
for(const p of Object.values(run.resolved)) {
    if(!p.visible || !p.content) continue;
    for(const value of [p.content.x,p.content.y,p.content.width,p.content.height])
        assert(Number.isFinite(value));
    assert(p.content.x>=IN.left-.01 && p.content.y>=IN.top-.01);
    assert(p.content.x+p.content.width<=640.5-IN.right+.01);
    assert(p.content.y+p.content.height<=480.25-IN.bottom+.01);
}

// Inactive/resting geometry remains exact for legacy deep-inward large surfaces.
const legacyInward={
    visible:true,evicted:false,along:216,inward:718.75,
    span:520.5,depth:132.44,shrunk:true,
    content:{x:224.5,y:766.75,width:503.5,height:115.44}
};
const legacyRecord=placedPanel(1200,900,
    {left:11.5,right:17.25,top:39.5,bottom:13.75},
    "top",216,520.5,150.5,1,8.5,[],true,legacyInward);
sameRect(legacyRecord.content,legacyInward.content,
    "inactive large-surface inward geometry");
approx(legacyRecord.targetDepth,851.19,
    "inactive large-surface target depth");

// Output locality remains structural: each controller resolves only its members.
let firstOutput=resolveMembers([feature,notes]);
let secondOutput=resolveMembers([system,center]);
assert(firstOutput.resolved!==secondOutput.resolved);
assert(!secondOutput.resolved.leftPanel);

// The resolver never mutates allocator inputs.
const snapshot=JSON.stringify([feature.request,notes.request,feature.placement,notes.placement]);
resolveMembers([feature,notes]);
assert.equal(JSON.stringify([feature.request,notes.request,feature.placement,notes.placement]),snapshot);

console.log("PASS: automatic semantic borrowing, hover override, swap/custom geometry, blockers, restore, bounds and record/input truth");
"""
result = subprocess.run(["node", "-e", program], cwd=ROOT)
raise SystemExit(result.returncode)
