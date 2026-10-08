const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const policy={};vm.createContext(policy);
vm.runInContext(fs.readFileSync('modules/abyss/looks/PowerRenderQuality.js','utf8').replace(/^\.pragma library\s*/,''),policy);
for(const profile of ['power-saver','balanced','performance','unavailable']) {
 for(const manual of ['performance','balanced','quality','unknown']) {
  assert.equal(policy.abyss(manual,false,profile),['performance','balanced','quality'].includes(manual)?manual:'balanced');
  assert.equal(policy.abyss(manual,true,profile),profile==='power-saver'?'performance':profile==='performance'?'quality':'balanced');
  for(const shell of ['performance','balanced','quality']) {
   assert.equal(policy.wull(manual,false,profile,shell),shell==='performance'||manual==='performance'?'performance':'quality');
   assert.equal(policy.wull(manual,true,profile,shell),shell==='performance'||profile==='power-saver'?'performance':'quality');
  }
 }
}
// The explicit higher tier never bypasses shell Performance or increases
// the pre-existing automatic profile cost.
for(const profile of ['power-saver','balanced','performance','unavailable']) {
 for(const shell of ['performance','balanced','quality']) {
  assert.equal(policy.wull('detailed',false,profile,shell),shell==='performance'?'performance':'detailed');
  assert.equal(policy.wull('detailed',true,profile,shell),shell==='performance'||profile==='power-saver'?'performance':'quality');
 }
}
assert.equal(policy.wullLabel('performance'),'Performance');
assert.equal(policy.wullLabel('quality'),'Balanced');
assert.equal(policy.wullLabel('detailed'),'Quality');
assert.equal(policy.wullLabel('unknown'),'Balanced');
console.log('PASS: live-profile policy matrix and manual mode');
