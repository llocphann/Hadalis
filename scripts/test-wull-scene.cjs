#!/usr/bin/env node
// Exercise actual production geometry and attention, including every path point.
const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const load=(name,imports={})=>{
    const scope=vm.createContext(imports);
    vm.runInContext(fs.readFileSync(`modules/abyss/companion/${name}.js`,'utf8')
        .replace(/^\.(?:pragma|import).*\n/gm,''),scope);
    return scope;
};
const Slots=load('WullSurfacePlacement'), api=load('WullScene',{Slots}), attention=load('WullAttention');
let cases=0, paths=0;
const scene=(scale=1,width=1280,height=820)=>({width,height,scale,hostWidth:112*scale,hostHeight:98*scale,
    insets:{top:44,right:20,bottom:20,left:20},records:[],blockers:[],surfaces:[]});
const checkPath=(s,from,to,route)=>{
    assert.equal(route.qualified,true);let previous=from;
    for(const next of route.points){
        for(let i=0;i<=100;i++){
            const t=i/100,p={x:previous.x+(next.x-previous.x)*t,y:previous.y+(next.y-previous.y)*t};
            assert.equal(api.clearAt(s,p),true,JSON.stringify({p,route}));cases++;
        }
        previous=next;
    }
    assert.equal(previous.x,to.x);assert.equal(previous.y,to.y);paths++;
};
const seen=new Set();
for(const scale of [.65,1,1.5]) for(const [w,h] of [[800,600],[1280,820],[1920,1080]]) {
    const s=scene(scale,w,h);
    for(let i=0;i<80;i++){
        const p=api.appearance(s,.8,(i%4+.1)/4,(i+.5)/80);
        assert.equal(p.qualified,true);assert.equal(api.clearAt(s,p),true);
        assert.equal(p.grounded,p.edge==='bottom','only the lower water rim supports a walk');
        seen.add(p.edge);cases++;
    }
}
assert.deepEqual([...seen].sort(),['bottom','left','right','top']);
const s=scene();
const left={rect:{x:20,y:130,width:230,height:500},edge:'left',key:'leftPanel'};
const right={rect:{x:1030,y:130,width:230,height:500},edge:'right',key:'rightPanel'};
const popup={rect:{x:510,y:320,width:250,height:230},edge:'top',key:'popup'};
s.surfaces=[left,right,popup];s.blockers=s.surfaces.map(v=>v.rect);
const points=api.surfacePoints(s);
assert.ok(points.some(p=>p.key==='leftPanel'));assert.ok(points.some(p=>p.key==='rightPanel'));
assert.ok(points.some(p=>p.key==='popup'&&p.grounded));
let surfaces=0;
for(let i=0;i<100;i++){
    const p=api.appearance(s,(i+.5)/100,.3,.7);
    assert.equal(api.clearAt(s,p),true);if(p.kind==='surface')surfaces++;cases++;
}
assert.equal(surfaces,35,'35% initial surface chance, with free edges still eligible');
const ground=api.edgePoint(s,'bottom',.35),groundTo=api.edgePoint(s,'bottom',.65);
const walking=api.path(s,ground,groundTo);
assert.equal(walking.mode,'walk');checkPath(s,ground,groundTo,walking);
const air={x:300,y:80},airTo={x:810,y:620};
const flight=api.path(s,air,airTo);
assert.equal(flight.mode,'fly');assert.ok(flight.points.length>1,'route goes around the actual popup');
checkPath(s,air,airTo,flight);
for(const point of points) if(api.clearAt(s,air)){
    const route=api.path(s,air,point);if(route.qualified)checkPath(s,air,point,route);
}
const empty=scene();
const drop=api.drop(empty,38,330,{x:100,y:100});
assert.equal(drop.grounded,false);
const exit=api.nearestWater(empty,drop);
assert.equal(exit.qualified,true);assert.equal(exit.placement.edge,'left','hide uses nearby water after a drag');
checkPath(empty,drop,exit.placement,exit.route);
const landed=api.drop(empty,340,empty.height-empty.insets.bottom-empty.hostHeight-5,{x:100,y:100});
assert.equal(landed.grounded,true,'dropping near the lower rim lands on it');
const retained=api.drop(s,popup.rect.x,popup.rect.y,air);
assert.equal(retained.x,air.x);assert.equal(retained.y,air.y,'occupied drop keeps the last safe position');
for(const bad of [NaN,Infinity,-Infinity]) assert.equal(api.drop(empty,bad,5,air).qualified,false);
for(const bad of [null,{...empty,records:[{edge:'top',along:NaN,span:20}]},
    {...empty,blockers:[{x:0,y:0,width:NaN,height:5}]},{...empty,width:70},
    {...empty,surfaces:[{rect:popup.rect,edge:'diagonal'}]}]) {
    assert.equal(api.valid(bad),false);assert.equal(api.appearance(bad,.4,.5,.6).qualified,false);
}
// Both endpoints may be on the floor, yet crossing an obstacle must fly.
const obstruction=scene();obstruction.blockers=[{x:540,y:640,width:190,height:160}];
const from=api.edgePoint(obstruction,'bottom',.25),to=api.edgePoint(obstruction,'bottom',.75);
const around=api.path(obstruction,from,to);
assert.equal(around.mode,'fly');checkPath(obstruction,from,to,around);
const plain=v=>JSON.parse(JSON.stringify(v));
assert.deepEqual(plain(attention.resolve(true,1,0,true,-1,0,0,0,'idle')),{x:.82,y:0,source:'travel'});
assert.equal(attention.resolve(true,0,-1,true,1,1,0,0,'idle').y,-.62);
for(const expression of ['sleepy','working','thinking','sad'])
    assert.equal(attention.resolve(false,0,0,true,1,1,.1,.2,expression).source,'activity');
assert.equal(attention.resolve(false,0,0,false,-1,0,.1,.2,'idle').source,'curiosity');
assert.equal(attention.resolve(false,0,0,true,5,-5,0,0,'idle').x,1);
assert.equal(attention.resolve(false,0,0,true,NaN,Infinity,0,0,'idle').y,0);
console.log(`WULL_FOUR_EDGE_SURFACE_WALK_FLIGHT_DROP_ATTENTION_PASS cases=${cases} paths=${paths}`);
