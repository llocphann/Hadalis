const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const context = vm.createContext({});
vm.runInContext(fs.readFileSync('modules/abyss/companion/WullCloudOrbit.js','utf8')
    .replace(/^\.pragma.*\n/,''),context);
let cases = 0;
for (const [width,height] of [[640,480],[1366,768],[1920,1080]]) {
    for (const edge of ['top','bottom','left','right']) {
        for (const scale of [.45,.65,1,1.35,1.7]) {
            for (const ratio of [.06,.25,.5,.75,.94]) {
                const vertical = edge==='left'||edge==='right';
                const actor = {width:vertical ? 98 : 112,height:vertical ? 112 : 98,scale,edge};
                const angle = {top:180,bottom:0,left:90,right:-90}[edge]*Math.PI/180;
                actor.sideAlignment = -(actor.width/2-34.3)*Math.sin(angle);
                actor.floorAlignment = (actor.height/2-34.3)*Math.cos(angle);
                const cx = edge==='left' ? 18+34.3*scale : edge==='right' ? width-18-34.3*scale : width*ratio;
                const cy = edge==='top' ? 18+34.3*scale : edge==='bottom' ? height-18-34.3*scale : height*ratio;
                actor.x = cx-actor.width/2-actor.sideAlignment*scale;
                actor.y = cy-actor.height/2-actor.floorAlignment*scale;
                const result = context.layout(width,height,actor);
                assert(result.available,JSON.stringify({width,height,edge,scale,ratio}));
                const [a,b] = result.nodes;
                for (const n of result.nodes) {
                    assert(Object.values(n).every(Number.isFinite));
                    assert(n.width<=48 && n.height<=42,'clouds grew into a toolbar');
                    assert(n.x>=8 && n.y>=8 && n.x+n.width<=width-8 && n.y+n.height<=height-8,
                        'orbit spilled outside its owning output');
                    const nx = n.x+n.width/2,ny = n.y+n.height/2;
                    assert(edge==='top' ? ny>cy : edge==='bottom' ? ny<cy : edge==='left' ? nx>cx : nx<cx,
                        'an action appeared behind the screen rim');
                }
                assert(a.x+a.width<=b.x || b.x+b.width<=a.x || a.y+a.height<=b.y || b.y+b.height<=a.y,
                    'cloud actions overlap');
                const ax=a.x+a.width/2-cx,ay=a.y+a.height/2-cy;
                const bx=b.x+b.width/2-cx,by=b.y+b.height/2-cy;
                const ux=Math.cos(result.axisAngle),uy=Math.sin(result.axisAngle);
                assert(Math.abs(Math.hypot(ax,ay)-Math.hypot(bx,by))<1e-6,'orbit distances lost symmetry');
                assert(Math.abs((ax-bx)*ux+(ay-by)*uy)<1e-6,'actions are not mirrored across the orbit axis');
                assert(Math.abs((ax+bx)*uy-(ay+by)*ux)<1e-6,'pair midpoint left the orbit axis');
                cases++;
            }
        }
    }
}
const crowded = context.layout(90,80,{x:0,y:0,width:90,height:80,scale:1,edge:'bottom'});
assert(!crowded.available,'an impossible orbit intercepted a crowded output');
console.log('WULL_CLOUD_ORBIT_GEOMETRY_PASS '+cases+' symmetricFourEdges mirroredAngles equalDistances cornerClearance scaledBounds inwardOrbit noOverlap crowdedHide');
