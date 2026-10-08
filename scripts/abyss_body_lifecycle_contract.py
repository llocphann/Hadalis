"""Evaluate the real Loader binding against surface-lifetime contracts."""
import re
import subprocess


def verify_loader_residency(host: str) -> None:
    loader = host[host.index("id: content\n"):]
    binding = re.search(r"\n\s*active:([\s\S]*?)\n\s*source:", loader)
    assert binding, "body content must expose a Loader activation binding"
    subprocess.run(["node", "-e", r'''
const assert=require('node:assert/strict'),vm=require('node:vm');
const closed={embeddedItem:null,residentContent:false,visualResident:false,warmHeld:false};
const cases=[
 ['cold closed',{},true,false],
 ['open/retracting', {visualResident:true},true,true],
 ['closed resident Dock',{residentContent:true},true,true],
 ['closed warm canvas',{warmHeld:true},true,true],
 ['expired warm canvas',{},true,false],
 ['embedded content',{embeddedItem:{},residentContent:true,visualResident:true,warmHeld:true},true,false],
 ['deferred startup',{residentContent:true,visualResident:true,warmHeld:true},false,false],
];
for(const [label,values,ready,expected] of cases) {
 const actual=vm.runInNewContext(process.argv[1],{
  root:{...closed,...values},GlobalStates:{deferredPanelsReady:ready}
 },{timeout:100});
 assert.equal(actual,expected,label);
}
''', binding.group(1)], check=True)
