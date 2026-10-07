const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const folder='modules/abyss/companion/';
function load(name){const api=vm.createContext({});vm.runInContext(fs.readFileSync(folder+name,'utf8').replace(/^\.pragma library\s*/,''),api);return api}
const aqua=load('AquaMotionData.js'),octo=load('OctoMotionData.js'),rig=load('OctoRig.js'),prefs=load('WullPreferences.js');
assert.equal(Object.keys(aqua.clips).length,30);assert.equal(Object.keys(octo.clips).length,30);
assert.equal(aqua.clips.sink,undefined);assert.equal(aqua.clips.pulled.duration,octo.clips.sink.duration);
assert.equal(octo.clips.sink.duration,5600);assert.equal(aqua.clips.push.duration,5600);assert.equal(octo.clips.pull.duration,5600);
const common=Object.keys(aqua.clips).filter(k=>!['push','pulled'].includes(k));
assert.deepEqual(common.sort(),Object.keys(octo.clips).filter(k=>!['sink','pull'].includes(k)).sort());
let sampled=0;
for(const module of [aqua,octo])for(const [name,clip] of Object.entries(module.clips)){
    assert.ok(clip.duration>0 && clip.duration<=24000);
    for(const [channel,keys] of Object.entries(clip.tracks)){
        assert.equal(keys[0][0],0);assert.ok(Math.abs(keys.at(-1)[0]-1)<1e-6);
        for(let i=0;i<=100;i++){
            const t=i/100,v=module.sample(name,channel,t);assert.ok(Number.isFinite(v));sampled++;
            if(channel.startsWith('scale'))assert.ok(v>=.6 && v<=1.15);
        }
    }
}
for(const character of ['aqua','octo'])for(const alternate of [false,true]){
    const parsed=prefs.normalize(JSON.parse(JSON.stringify({...prefs.defaults(),character,alternateCompanions:alternate})));
    assert.equal(parsed.character,character);assert.equal(parsed.alternateCompanions,alternate);
}
assert.equal(prefs.normalize({character:'evil',alternateCompanions:'true'}).character,'aqua');
assert.equal(prefs.normalize({alternateCompanions:'true'}).alternateCompanions,false);
assert.equal(rig.geometry.tentacles,4);
assert.ok(rig.geometry.rootRadius>8 && rig.geometry.tipRadius>3);
for(let i=0;i<rig.geometry.tentacles;i++){
    for(const action of ['walk','run','fly','wave','press','reach','pull','sink']){
        for(let p=0;p<=1;p+=.05){
            const c=rig.controls(i,octo.sample(action,`tentacle${i}Curl`,p),octo.sample(action,`tentacle${i}Lift`,p),octo.sample(action,`tentacle${i}Reach`,p));
            for(let t=0;t<=1;t+=.1){const v=rig.point(c,t);assert.ok(['x','y','z','r'].every(k=>Number.isFinite(v[k])));assert.ok(v.r>0)}
        }
    }
    assert.ok(octo.clips.walk.tracks[`tentacle${i}Curl`]);assert.ok(octo.clips.fly.tracks[`tentacle${i}Lift`]);
}
assert.ok(octo.sample('walk','tentacle0Lift',.75)>0);assert.equal(octo.sample('walk','tentacle1Lift',.75),0);
assert.equal(octo.sample('pull','gripRise',.6),1);assert.equal(octo.sample('pull','gripWrap',.6),1);
for(let i=0;i<4;i++)for(let p=0;p<=1;p+=.01){
    const c=rig.gripControls(i,octo.sample('pull','gripRise',p),octo.sample('pull','gripWrap',p));
    assert.ok(c.every(v=>['x','y','z','r'].every(k=>Number.isFinite(v[k]))));
}
assert.ok(rig.gripControls(0,1,1)[3].x>20 && rig.gripControls(3,1,1)[3].x<-20);
assert.ok(rig.gripControls(0,1,1)[2].z>30 && rig.gripControls(1,1,1)[2].z<0);
assert.ok(octo.sample('wave','tentacle0Lift',.5)>14);
assert.ok(octo.sample('buttplant','pitch',.6)<-60);assert.ok(aqua.sample('buttplant','pitch',.6)<-60);
console.log(`COMPANION_CAST_CURVES_PREFS_RIG_PASS Aqua=30 Octo=30 sampled=${sampled}`);
