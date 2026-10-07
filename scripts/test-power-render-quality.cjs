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
// Quality retains the old Balanced renderer; no route can select former tier 2.
const prefs={};vm.createContext(prefs);
vm.runInContext(fs.readFileSync('modules/abyss/companion/WullPreferences.js','utf8').replace(/^\.pragma library\s*/,''),prefs);
for(const old of ['balanced','quality','unknown']) {
 assert.equal(prefs.normalize({renderQuality:old}).renderQuality,'quality');
 assert.equal(prefs.renderTier(old,'quality'),1);
}
assert.equal(prefs.normalize({renderQuality:'performance'}).renderQuality,'performance');
assert.deepEqual(Array.from(prefs.qualities),['performance','quality']);
console.log('PASS: live-profile policy matrix, manual mode, two-tier migration and no former high tier');
