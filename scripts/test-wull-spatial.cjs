#!/usr/bin/env node
const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
function load(path){const s=vm.createContext({});vm.runInContext(fs.readFileSync(path,'utf8').replace(/^\.pragma library\s*/m,''),s);return s;}
const pose=load('modules/abyss/companion/WullPose.js'),curves=load('modules/abyss/companion/WullMotionData.js');
const near=(a,b)=>assert.ok(Math.abs(a-b)<1e-9,`${a} != ${b}`);
let cases=0;
for(const yaw of [-180,-90,-15,0,60,180])for(const pitch of [-78,-68,0,40,78])for(const roll of [-30,0,25]){
    const r=pose.rotation(yaw,pitch,roll);
    for(let i=0;i<3;i++)for(let j=0;j<3;j++)near(r[i*3]*r[j*3]+r[i*3+1]*r[j*3+1]+r[i*3+2]*r[j*3+2],i===j ? 1 : 0);
    const p=pose.project(r,12,-10,26,1.03,.96);near(Math.hypot(p.x,p.y,p.z),Math.hypot(12*1.03,-10*.96,26/(1.03*.96)));
    const matrix=pose.faceMatrix(r,1.03,.96),face=pose.project(r,12,-10,26,1.03,.96);
    near(matrix[0]*50+matrix[1]*56.14+matrix[3],38+face.x);
    near(matrix[4]*50+matrix[5]*56.14+matrix[7],46.14-face.y);cases++;
}
for(const clip of ['buttplant','faceplant','ice','fallVanish'])for(let i=0;i<=100;i++){
    const t=i/100,sx=curves.sample(clip,'scaleX',t),sy=curves.sample(clip,'scaleY',t);
    near(sx*sy*pose.depthScale(sx,sy),1);assert.ok(sy>=.95,'fall flattened the body');
}
assert.ok(curves.sample('buttplant','pitch',.6)<-60);
assert.ok(curves.sample('faceplant','pitch',.6)>70);
const seated=pose.project(pose.rotation(-37,-68,-12),0,-15,26);
assert.ok(seated.y>15 && seated.z>0,'seated face did not rotate upwards into depth');
console.log(`WULL_SPATIAL_ROTATION_VOLUME_FACE_PROJECTION_PASS cases=${cases}`);
