#!/usr/bin/env node
// Geometry contracts for complete Blender jump/flight envelopes and gravity.
const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const load=(file,scope={})=>{
    const api=vm.createContext(scope);
    vm.runInContext(fs.readFileSync(file,'utf8').replace(/^\.(?:pragma|import).*$/gm,''),api);
    return api;
};
const slots=load('modules/abyss/companion/WullSurfacePlacement.js');
const scene=load('modules/abyss/companion/WullScene.js',{Slots:slots});
const curves=load('modules/abyss/companion/WullMotionData.js');
for (const name of ['run','fly','jump','drag','fall','land','press','reach','inspect','wave']) {
    assert.ok(curves.clips[name]);
    assert.equal(Object.keys(curves.clips[name].tracks).some(k=>/^foot[23]/.test(k)),false);
}
assert.ok(curves.sample('fly','arm0Z',.22)>8,'flight has an actual propulsion stroke');
assert.ok(curves.sample('fly','foot0Z',.35)>8,'flight tucks its two feet');
assert.ok(curves.sample('run','foot0Z',.75)>8);
assert.equal(curves.sample('run','foot1Z',.75),0);
assert.ok(curves.sample('fall','scaleY',.5)>1.04);
assert.ok(curves.sample('land','scaleY',0)<.94);
let cases=0;
for (const scale of [.65,1,1.5]) {
    const base={width:1400,height:1000,hostWidth:112*scale,hostHeight:98*scale,scale,
        insets:{top:20,right:20,bottom:20,left:20},records:[],blockers:[],surfaces:[]};
    const from={x:480,y:190}, floor=scene.landingBelow(base,from);
    assert.ok(floor.qualified && floor.grounded);
    assert.equal(floor.support.key,'bottom');
    assert.ok(scene.clearSegment(base,from,floor));
    const body={x:420,y:640,width:340,height:160,walkable:false};
    const s={...base,blockers:[body],surfaces:[{key:'popup',edge:'left',rect:body,radius:24}]};
    const landing=scene.landingBelow(s,from);
    assert.ok(landing.qualified && landing.grounded);
    assert.equal(landing.support.key,'popup','land on the first actual upper rim');
    const miss={...s,blockers:[{...body,width:40}],surfaces:[]};
    assert.equal(scene.landingBelow(miss,{x:420,y:190}).qualified,false,
        'a non-walkable obstruction cannot be crossed to reach the screen floor');
    const a={x:450,y:floor.y},b={x:550,y:floor.y},height=42*scale;
    assert.ok(scene.clearArc(base,a,b,height));
    assert.equal(scene.clearArc({...base,blockers:[{x:500,y:a.y-height-12,width:12,height:18}]},a,b,height),false,
        'overhead obstacles reject the complete arc, including between keyframes');
    assert.equal(scene.clearArc(base,{x:450,y:20}, {x:550,y:20},height),false);
    for (const clip of ['jump','fly']) for (let i=0;i<=1000;i++) {
        const phase=i/1000,h=curves.sample(clip,'height',phase);
        assert.ok(h>=0 && h<=1);
        const t=clip==='jump' ? curves.sample(clip,'journey',phase) : phase;
        assert.ok(scene.clearAt(base,{x:a.x+(b.x-a.x)*t,y:a.y-height*h}));
        cases++;
    }
    // A falling path uses a quadratic position law: acceleration increases
    // successive displacements, without ever skipping through an obstacle.
    let last=from.y,delta=0;
    for (let i=1;i<=100;i++) {
        const y=from.y+(floor.y-from.y)*(i/100)**2;
        assert.ok(y-last>=delta-1e-9);
        assert.ok(scene.clearSegment(base,{x:from.x,y:last},{x:from.x,y}));
        delta=y-last;last=y;cases++;
    }
}
assert.equal(scene.landingBelow(null,{x:0,y:0}).qualified,false);
console.log(`WULL_BLENDER_AIRBORNE_SWEEP_AND_LANDING_PASS cases=${cases}`);
