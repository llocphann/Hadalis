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

// Perpendicular placement must stay bounded even on a very small logical view.
for (const [w,h] of [[480,320],[800,600],[960,600],[1920,1200]]) {
    for (const owner of ['top','bottom','left','right']) {
        const ins=insets(8,owner,48,true);
        const sides=[panel(w,h,ins,'left',90,h-180,370,1,20),panel(w,h,ins,'right',90,h-180,390,1,20)];
        const rec=panel(w,h,ins,owner,100,380,320,1,20,sides);
        const c=rec.content;
        assert(c.x>=0 && c.y>=0 && c.x+c.width<=w && c.y+c.height<=h);
    }
}
// Flood-fill the actual inverse-opening/smooth-union distance. Each layout
// retains one workspace opening; no sealed corner pockets may appear.
for (const owner of ['top','bottom','left','right']) {
    const w=1100,h=700,ins=insets(8,owner,48,true);
    const side=panel(w,h,ins,'right',90,480,360,1,20);
    const popup=panel(w,h,ins,owner,390,380,300,1,20,[side]);
    const dock=panel(w,h,ins,'bottom',350,400,80,1,12,[side,popup]);
    for (const records of [[],[dock],[side],[popup],[dock,side],[popup,side],[popup,side,dock]]) {
        const cols=110,rows=70,seen=new Set(); let components=0;
        for(let y=0;y<rows;y++) for(let x=0;x<cols;x++) {
            const index=y*cols+x;
            if(seen.has(index) || distance((x+.5)*10,(y+.5)*10,w,h,ins,34,records,24,29)<=0) continue;
            components++;
            const queue=[index]; seen.add(index);
            while(queue.length) {
                const cell=queue.pop(),cx=cell%cols,cy=Math.floor(cell/cols);
                for(const [nx,ny] of [[cx-1,cy],[cx+1,cy],[cx,cy-1],[cx,cy+1]]) {
                    const next=ny*cols+nx;
                    if(nx<0 || nx>=cols || ny<0 || ny>=rows || seen.has(next)) continue;
                    if(distance((nx+.5)*10,(ny+.5)*10,w,h,ins,34,records,24,29)>0) { seen.add(next); queue.push(next); }
                }
            }
        }
        assert.equal(components,1,'one clean workspace opening: '+owner);
    }
}
assert.deepEqual(barZones({left:['media','tray'],centerLeft:['media','resources'],center:['workspaces'],right:['sysTray','weather']},false,{resources:false}),[['media','tray'],[],['workspaces'],[],['weather']]);
assert.deepEqual(barZones({top:['clock'],center:['workspaces'],bottom:['media']},true,{}),[['clock'],[],['workspaces'],[],['media']]);
const host = require('node:fs').readFileSync('modules/abyss/AbyssPerimeter.qml','utf8');
assert(host.includes('exclusionMode: ExclusionMode.Ignore'));
assert(host.includes('exclusiveZone: 0'));
assert(host.includes('mask: Region {}'));
assert(host.includes('model: Quickshell.screens'));
"""
subprocess.run(["node", "-e", program], cwd=root, check=True)
print("ok - connected four-edge SDF, orientations, content bounds and output policy")
