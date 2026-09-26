#!/usr/bin/env python3
"""Evaluate the same geometry/SDF contract consumed by the QML field."""
from pathlib import Path
import subprocess
root = Path(__file__).resolve().parents[1]
program = (root / "modules/abyss/looks/AbyssGeometry.js").read_text() + r"""
const assert = require('node:assert/strict');
assert.equal(edge(false,false),'top'); assert.equal(edge(false,true),'bottom');
assert.equal(edge(true,false),'left'); assert.equal(edge(true,true),'right');
assert(targets('DP-2',['missing'],['DP-1','DP-2']));
assert(!targets('DP-2',['DP-1'],['DP-1','DP-2']));
for (const scale of [1,1.25,1.5,2]) {
    const w=1920/scale,h=1200/scale;
    for (const owner of ['top','bottom','left','right']) {
        const ins=insets(8,owner,48,true);
        assert.equal(ins[owner],48);
        for (const dock of ['top','bottom','left','right']) {
            for (const progress of [0,0.25,0.5,1,1.025]) {
                const records=[panel(w,h,ins,dock,200,300,70,progress,20),
                    panel(w,h,ins,'right',100,h-180,320,1,20),
                    panel(w,h,ins,owner,200,360,250,1,20)];
                for (const rec of records) {
                    const c=rec.content;
                    assert(c.x>=0 && c.y>=0 && c.width>=0 && c.height>=0);
                    assert(c.x+c.width<=w && c.y+c.height<=h);
                    if (c.width>0 && c.height>0)
                        assert(distance(c.x+c.width/2,c.y+c.height/2,w,h,ins,34,records,24)<0);
                }
                assert(distance(w/2,h/2,w,h,ins,34,records,24)>0, 'clean workspace center');
                // Every physical edge remains one connected body, even with
                // intersecting deformations and fractional logical dimensions.
                for(let i=1;i<100;i++) {
                    assert(distance(w*i/100,0,w,h,ins,34,records,24)<0);
                    assert(distance(w*i/100,h,w,h,ins,34,records,24)<0);
                    assert(distance(0,h*i/100,w,h,ins,34,records,24)<0);
                    assert(distance(w,h*i/100,w,h,ins,34,records,24)<0);
                }
            }
        }
    }
}
const host = require('node:fs').readFileSync('modules/abyss/AbyssPerimeter.qml','utf8');
assert(host.includes('exclusionMode: ExclusionMode.Ignore'));
assert(host.includes('exclusiveZone: 0'));
assert(host.includes('mask: Region {}'));
assert(host.includes('model: Quickshell.screens'));
"""
subprocess.run(["node", "-e", program], cwd=root, check=True)
print("ok - connected four-edge SDF, orientations, content bounds and output policy")
