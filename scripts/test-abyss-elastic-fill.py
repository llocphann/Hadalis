#!/usr/bin/env python3
"""Elastic Fill coexistence, hover ownership, geometry and animation contracts."""
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
for token in ('import "looks/AbyssElasticFill.js" as ElasticFill',"readonly property var baseBodyPlacements: BodyPlacement.arrange(","readonly property var bodyPlacements: ElasticFill.resolve(","function nextElasticFillInteractionOrder(): int"): assert token in controller
for token in ('property bool elasticFillAnchor: false',"elasticFillAnchor:root.elasticFillAnchor","property real elasticLimitProgress:","Behavior on elasticLimitProgress","elasticLimits:"): assert token in host
assert perimeter.count('elasticFillGroup: edge === "left"')==2
for token in ("Presentation.nearbyEdge(edge,along,span,",'elasticNearbyEdge === "left"','elasticNearbyEdge === "right"',"elasticFillAnchor: elasticFillGroup.length > 0"): assert token in perimeter
for token in ("elasticFillAnchor","var delayed=members.filter(","ordered.splice(lastAnchor+1+d,0,delayed[d])"): assert token in placement
for token in ("function _elasticPanelRect(member)","function _elasticDirections(owner,members)","var originalPanel=_elasticPanelRect(owner)"): assert token in elastic
assert "Config." not in elastic and "placement.elasticLimits === true" in geometry and "tangentFlush" in geometry
assert "elasticLimits:placement.elasticLimits === true" in motion
program=geometry+"\n"+placement+"\n"+elastic+"\n"+motion+r"""
const assert=require('node:assert/strict');
function overlap(a,b,g=0){return a.x<b.x+b.width+g&&a.x+a.width+g>b.x&&a.y<b.y+b.height+g&&a.y+a.height+g>b.y}
function close(a,b,t=.15){return Math.abs(a-b)<t}
function req(w,h,ins,id,e,o,s,d,a,p,g,an,hov,ho,l=false,st=""){const r=panel(w,h,ins,e,a,s,d,1,p,[],l);return{id,open:true,order:o,priority:0,padding:p,allowInward:true,stackPolicy:st,stackProximity:24,minSpan:Math.min(r.span,l?520:220),minDepth:Math.min(r.targetDepth,l?360:120),elasticFillGroup:g,elasticFillAnchor:an,elasticFillHovered:hov,elasticFillOrder:ho,record:r}}
let active=0,noSlack=0,tails=0;
for(const [w,h] of [[640,360],[768,480],[1024,600],[1280,720],[1366,768],[1600,900],[1920,1080],[2560,1440],[3440,1440]]){const ins={left:16,top:48,right:16,bottom:16},ss=Math.min(h-ins.top-ins.bottom-72,Math.max(320,h*.7));for(const se of ["left","right"])for(const pe of ["top","bottom"]){const q=se==="left",g=q?"quickNotesSidebar":"notificationsSidebar",pd=q?Math.min(300,h*.8):Math.min(560,h*.8),l=pd>h*.42,ps=Math.min(420,w-60),pa=q?-220:w-ps+220;for(const [so,po] of [[1,2],[3,2],[10,1]])for(const own of ["side","popup"]){const s=req(w,h,ins,"side",se,so,ss,Math.min(460,w*.8),(h-ss)/2,20,g,false,own==="side",own==="side"?20:10,false),p=req(w,h,ins,"popup",pe,po,ps,pd,pa,14,g,true,own==="popup",own==="popup"?20:10,l,"pyramid"),b=arrange([s,p],w,h,ins);assert(b.side?.visible&&b.popup?.visible);assert.equal(b.popup.inward,0);assert(b.side.inward>0);const f=resolve([s,p],b,24),ow=f[own];if(ow.elasticFilled!==true){noSlack++;continue}const ex=pe==="bottom"?(own==="popup"?"top":"bottom"):(own==="popup"?"bottom":"top");assert.equal(ow.elasticDirection,ex);assert(!overlap(f.side.content,f.popup.content,23.9));const sp=_elasticPanelRect({request:s,placement:b.side}),pp=_elasticPanelRect({request:p,placement:b.popup}),op=_elasticPanelRect({request:own==="side"?s:p,placement:ow});if(own==="side")assert(ex==="bottom"?close(op.y+op.height,pp.y+pp.height):close(op.y,pp.y));else assert(ex==="top"?close(op.y,sp.y):close(op.y+op.height,sp.y+sp.height));for(const [id,rq] of [["side",s],["popup",p]]){const pl=f[id],rr=placedPanel(w,h,ins,rq.record.edge,rq.record.along,rq.record.span,rq.record.targetDepth,1,rq.padding,[],id==="popup"?l:false,pl);assert(close(rr.content.x,pl.content.x)&&close(rr.content.y,pl.content.y)&&close(rr.content.width,pl.content.width)&&close(rr.content.height,pl.content.height));const t=Object.assign({},pl,{elasticFilled:false,elasticLimits:true}),tr=placedPanel(w,h,ins,rq.record.edge,rq.record.along,rq.record.span,rq.record.targetDepth,1,rq.padding,[],id==="popup"?l:false,t);assert(close(tr.content.x,pl.content.x)&&close(tr.content.y,pl.content.y)&&close(tr.content.width,pl.content.width)&&close(tr.content.height,pl.content.height));if(pl.elasticFilled===true)tails++}s.elasticFillHovered=false;p.elasticFillHovered=false;assert.equal(resolve([s,p],b,24),b);active++}}}}
assert(active>150&&tails>0);
{const w=1920,h=1080,ins={left:16,top:48,right:16,bottom:16},g="quickNotesSidebar",s=req(w,h,ins,"side","left",10,756,460,162,20,"g",false,false,0,false),q=req(w,h,ins,"quick","bottom",5,420,300,-203,14,"g",true,false,0,false,"pyramid"),x=req(w,h,ins,"generic","bottom",7,600,500,50,14,"",false,false,0,true,"pyramid"),r=req(w,h,ins,"remote","top",6,250,180,20,14,"",false,false,0,false);assert.deepEqual(_orderedRequests([s,x,r,q]).map(v=>v.id),["generic","remote","quick","side"])}
{const c=clonePlacement({visible:true,along:1,inward:2,span:3,depth:4,content:{x:1,y:2,width:3,height:4},elasticFilled:false,elasticLimits:true,elasticDirection:"top"});assert.equal(c.elasticLimits,true);assert.equal(c.elasticDirection,"top")}
console.log("Elastic Fill refined contract",{active,noSlack,tails});
"""
subprocess.run(["node","-e",program],cwd=ROOT,check=True)
spatial=presentation+r"""const assert=require('node:assert/strict');assert.equal(nearbyEdge("bottom",-203,420,1920,1080),"left");assert.equal(nearbyEdge("top",1703,420,1920,1080),"right");assert.equal(nearbyEdge("bottom",750,420,1920,1080),"");"""
subprocess.run(["node","-e",spatial],cwd=ROOT,check=True)
print("ok - Elastic Fill order, envelope, spatial scope and motion tail")
