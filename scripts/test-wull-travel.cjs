const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const travel=vm.createContext({});vm.runInContext(fs.readFileSync(path.join(__dirname,'../modules/abyss/companion/WullTravel.js'),'utf8').replace(/^\.pragma.*$/mg,''),travel);
for(const scale of [.5,1,1.25,2,3]) {
 const source={x:30*scale,y:200*scale},near={x:400*scale,y:200*scale,grounded:true},far={x:800*scale,y:200*scale,grounded:true};
 assert(!travel.usePortal(source,near,scale));assert(travel.usePortal(source,far,scale));assert(!travel.usePortal(source,{...far,grounded:false},scale));
 for(const sign of [-1,1]) {
  let last=0;
  for(let i=0;i<=100;i++) {const a=travel.rollingAngle(145*scale,i/100,sign,scale);assert(Number.isFinite(a));assert(a*sign>=last);last=a*sign;}
  assert.equal(Math.abs(travel.rollingAngle(145*scale,1,sign,scale)%360),0);
 }
}
for(const invalid of [NaN,Infinity,-Infinity,undefined])assert(!travel.usePortal({x:invalid,y:0},{x:800,y:0,grounded:true},1));
for(let i=0;i<=1000;i++) {const t=i/1000;assert(travel.reveal(t)>=0 && travel.reveal(t)<=1);assert(travel.opening(t)>=0 && travel.opening(t)<=1);if(t>=.4 && t<=.6)assert.equal(travel.reveal(t),0);}
assert.equal(travel.reveal(0),1);assert.equal(travel.reveal(1),1);assert.equal(travel.opening(0),0);assert.equal(travel.opening(1),0);
console.log('WULL_TRAVEL_PASS finite portal threshold hidden handover bounded lifetime whole rolling rotations');
