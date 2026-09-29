#!/usr/bin/env python3
"""Focused semantic vacancy regression for Abyss."""
from pathlib import Path
import subprocess
ROOT = Path(__file__).resolve().parents[1]
def read(p): return (ROOT / p).read_text(encoding="utf-8")
perimeter=read("modules/abyss/AbyssPerimeter.qml")
controller=read("modules/abyss/AbyssSurfaceController.qml")
host=read("modules/abyss/AbyssBodyHost.qml")
participant=read("modules/abyss/AbyssParticipant.qml")
geometry=read("modules/abyss/looks/AbyssGeometry.js")
resolver=read("modules/abyss/looks/AbyssVacancyBorrowing.js")
for token in ('vacancyRole: "featureSidebar"','vacancyRole: "systemSidebar"',
              'presentationKind === "quickNotes"','presentationKind === "notificationCenter"'):
    assert token in perimeter, token
for token in ('property string vacancyRole: ""','id: vacancyBodyHover',
              'vacancyRole: root.vacancyRole'):
    assert token in host + participant, token
assert 'VacancyBorrowing.resolve(' in controller

program=geometry+"\n"+resolver+r"""
const assert=require("node:assert/strict");
const W=1200,H=900,IN={left:16,right:16,top:16,bottom:16},G=24;
function m(id,role,edge,order,p){return{
 request:{id,open:true,order,padding:14,record:{edge,along:p.along,span:p.span,targetDepth:p.depth,depth:p.depth}},
 meta:{id,role,hovered:false,hoverOrder:0},placement:p};}
function run(ms){const ps=Object.fromEntries(ms.map(x=>[x.request.id,x.placement]));
 return{base:ps,out:resolve(ms.map(x=>x.request),ms.map(x=>x.meta),ps,W,H,IN,G)};}
function borrowers(o){return Object.entries(o).filter(([_,p])=>p.vacancyBorrowed).map(([id])=>id).sort();}
function collide(a,b,g=G){return a.x<b.x+b.width+g&&a.x+a.width+g>b.x&&a.y<b.y+b.height+g&&a.y+a.height+g>b.y;}

const feature=m("leftPanel","featureSidebar","left",31,{visible:true,along:86,inward:270,span:328,depth:228,content:{x:300,y:100,width:200,height:300}});
const notes=m("styledPopup0","quickNotes","bottom",32,{visible:true,along:30,inward:0,span:248,depth:228,content:{x:44,y:670,width:220,height:200}});
const system=m("rightPanel","systemSidebar","right",33,{visible:true,along:86,inward:270,span:328,depth:228,content:{x:700,y:100,width:200,height:300}});
const center=m("styledPopup1","notificationCenter","bottom",34,{visible:true,along:922,inward:0,span:248,depth:228,content:{x:936,y:670,width:220,height:200}});

// Exact live failure: four surfaces on two sides keep both independent automatic owners.
let r=run([feature,notes,system,center]);
assert.deepEqual(borrowers(r.out),["leftPanel","styledPopup1"]);
assert(!collide(r.out.leftPanel.content,r.out.styledPopup1.content));

// Hover affects only its own semantic pair when the other pair is independent.
notes.meta.hovered=true;notes.meta.hoverOrder=100;
r=run([feature,notes,system,center]);
assert.deepEqual(borrowers(r.out),["styledPopup0","styledPopup1"]);
assert(!collide(r.out.styledPopup0.content,r.out.styledPopup1.content));
notes.meta.hovered=false;

// Closing one peer collapses only that pair.
center.request.open=false;
r=run([feature,notes,system,center]);
assert.deepEqual(borrowers(r.out),["leftPanel"]);
center.request.open=true;

// Intended automatic owner per pair.
assert.deepEqual(borrowers(run([feature,notes]).out),["leftPanel"]);
assert.deepEqual(borrowers(run([system,center]).out),["styledPopup1"]);

// No vacancy is strict identity no-op.
const blocked=m("styledPopup0","quickNotes","left",99,{visible:true,along:86,inward:270,span:328,depth:228,content:{x:300,y:100,width:200,height:300}});
r=run([feature,blocked]);assert.strictEqual(r.out,r.base);

// Resolved content is the rendered geometry truth.
r=run([feature,notes]);
const rec=placedPanel(W,H,IN,"left",feature.request.record.along,feature.request.record.span,feature.request.record.targetDepth,1,14,[],true,r.out.leftPanel);
assert.deepEqual([rec.content.x,rec.content.y,rec.content.width,rec.content.height],
 [r.out.leftPanel.content.x,r.out.leftPanel.content.y,r.out.leftPanel.content.width,r.out.leftPanel.content.height]);

console.log("PASS: two semantic pairs borrow independently without collision");
"""
raise SystemExit(subprocess.run(["node","-e",program],cwd=ROOT).returncode)
